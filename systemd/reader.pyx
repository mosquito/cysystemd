from libc.stdlib cimport malloc, free
from libc.stddef cimport size_t
from libc.stdint cimport uint64_t, uint8_t
from cpython cimport dict

from sd_id128 cimport sd_id128_t
from sd_journal cimport (
    SD_JOURNAL_LOCAL_ONLY,
    SD_JOURNAL_RUNTIME_ONLY,
    SD_JOURNAL_SYSTEM,
    SD_JOURNAL_CURRENT_USER,
    SD_JOURNAL_SYSTEM_ONLY,
    sd_journal,
    sd_journal_close,
    sd_journal_enumerate_data,
    sd_journal_get_cursor,
    sd_journal_get_data_threshold,
    sd_journal_get_monotonic_usec,
    sd_journal_get_realtime_usec,
    sd_journal_next,
    sd_journal_open,
    sd_journal_open_directory,
    sd_journal_open_files,
    sd_journal_restart_data,
    sd_journal_seek_cursor,
    sd_journal_seek_head,
    sd_journal_seek_monotonic_usec,
    sd_journal_seek_realtime_usec,
    sd_journal_seek_tail,
    sd_journal_set_data_threshold,
    sd_journal_wait,
)

import os
from datetime import datetime
from uuid import UUID
from contextlib import contextmanager
from errno import errorcode
from enum import IntEnum
from dictproxyhack import dictproxy


cdef check_error_code(int code):
    if code >= 0:
        return

    code = -code

    if code in errorcode:
        error = errorcode[code]
        raise SystemError(os.strerror(code), error)



class JournalOpenMode(IntEnum):
    LOCAL_ONLY = SD_JOURNAL_LOCAL_ONLY
    RUNTIME_ONLY = SD_JOURNAL_RUNTIME_ONLY
    SYSTEM = SD_JOURNAL_SYSTEM
    CURRENT_USER = SD_JOURNAL_CURRENT_USER
    SYSTEM_ONLY = SD_JOURNAL_SYSTEM_ONLY


cdef enum READER_STATE:
    READER_CLOSED,
    READER_OPENED,
    READER_LOCKED,
    READER_NULL,


cdef str _check_dir_path(object path):
    path = str(path)

    if not os.path.exists(path):
        raise OSError('Directory not found')
    elif os.path.islink(path):
        c = 0
        while not os.path.islink(path):
            path = os.path.abspath(os.readlink(path))
            c += 1
            if c > 255:
                raise OSError("Link recursive reslolution error")

        return _check_dir_path(path)
    elif not os.path.isdir(path):
        raise OSError("It's not a directory")
    else:
        path = os.path.abspath(path)

    return path


cdef str _check_file_path(object path):
    path = str(path)

    if not os.path.exists(path):
        raise OSError('File not found')
    elif os.path.islink(path):
        c = 0
        while not os.path.islink(path):
            path = os.path.abspath(os.readlink(path))
            c += 1
            if c > 255:
                raise OSError("Link recursive reslolution error")

        return _check_file_path(path)
    elif not os.path.isfile(path):
        raise OSError("It's not a regular file")
    else:
        path = os.path.abspath(path)

    return path


cdef class JournalEntry:
    cdef sd_id128_t __boot_id
    cdef object __boot_uuid
    cdef char* cursor
    cdef uint64_t monotonic_usec
    cdef uint64_t realtime_usec
    cdef dict __data
    cdef object _data
    cdef object __date

    def __cinit__(self, Reader reader):
        cdef const void *data
        cdef size_t length

        self.__data = {}
        check_error_code(sd_journal_get_realtime_usec(reader.context, &self.realtime_usec))
        check_error_code(sd_journal_get_monotonic_usec(reader.context, &self.monotonic_usec, &self.__boot_id))
        check_error_code(sd_journal_get_cursor(reader.context, &self.cursor))

        sd_journal_restart_data(reader.context)

        while True:
            result = sd_journal_enumerate_data(reader.context, <const void **>&data, &length)

            if result == 0:
                break

            value = bytes((<char*> data)[:length]).decode()
            key, value = value.split("=", 1)

            if key in self.__data:
                if not isinstance(self._data[key], list):
                    self.__data[key] = [self.__data[key]]
                self.__data[key].append(value)
            else:
                self.__data[key] = value

        self._data = dictproxy(self.__data)
        self.__boot_uuid = UUID(bytes=self.__boot_id.bytes[:16])
        self.__date = datetime.fromtimestamp(self.get_realtime_sec())

    @property
    def cursor(self):
        return self.cursor

    cpdef float get_realtime_sec(self):
        return self.realtime_usec / 1000000

    def boot_id(self):
        return self.boot_id

    cpdef float get_monotonic_sec(self):
        return self.monotonic_usec / 1000000

    @property
    def date(self):
        return self.__date

    @property
    def data(self):
        return self._data

    def __dealloc__(self):
        free(self.cursor)

    def __repr__(self):
        return "<JournalEntry: %r>" % self.date


cdef class Reader:
    cdef sd_journal* context
    cdef char state
    cdef object flags

    def __init__(self):
        self.state = READER_NULL

    def open(self, flags=JournalOpenMode.CURRENT_USER):
        self.flags = JournalOpenMode(int(flags))

        with self._lock(opening=True):
            check_error_code(sd_journal_open(&self.context, self.flags.value))

    def open_directory(self, path):
        path = _check_dir_path(path)

        with self._lock(opening=True):
            cstr = path.encode()
            check_error_code(sd_journal_open_directory(&self.context, cstr, 0))

    def open_files(self, *file_names):
        file_names = tuple(map(_check_file_path, file_names))

        cdef char **paths = <char **>malloc(len(file_names) * sizeof(char*))

        for i, s in enumerate(file_names):
            cstr = s.encode()
            paths[i] = cstr

        try:
            with self._lock(opening=True):
                check_error_code(sd_journal_open_files(&self.context, paths, 0))
        finally:
            free(paths)

    @property
    def data_threshold(self):
        cdef size_t result
        check_error_code(sd_journal_get_data_threshold(self.context, &result))
        return result

    @data_threshold.setter
    def data_threshold(self, size):
        cdef size_t sz = size
        check_error_code(sd_journal_set_data_threshold(self.context, sz))

    @property
    def closed(self):
        return self.state == READER_CLOSED

    @property
    def locked(self):
        return self.state == READER_LOCKED

    @property
    def idle(self):
        return self.state == READER_OPENED

    @contextmanager
    def _lock(self, opening=False):
        if self.closed:
            raise RuntimeError("Can't lock closed reader")
        elif self.locked:
            raise RuntimeError("Reader locked")
        elif opening and self.state != READER_NULL:
            raise RuntimeError("Can't reopen opened reader")

        self.state = READER_LOCKED
        try:
            yield
        finally:
            self.state = READER_OPENED

    cpdef seek_head(self):
        check_error_code(sd_journal_seek_head(self.context))
        return True

    cpdef seek_tail(self):
        check_error_code(sd_journal_seek_tail(self.context))
        return True

    cpdef seek_monotonic_usec(self, boot_id: UUID, uint64_t usec):
        cdef sd_id128_t cboot_id
        cboot_id.bytes = boot_id.bytes
        check_error_code(sd_journal_seek_monotonic_usec(self.context, cboot_id, usec))
        return True

    cpdef seek_realtime_usec(self, uint64_t usec):
        cdef uint64_t cusec = usec
        check_error_code(sd_journal_seek_realtime_usec(self.context, cusec))
        return True


    cpdef seek_cursor(self, bytes cursor):
        cdef char* ccursor = cursor
        check_error_code(sd_journal_seek_cursor(self.context, ccursor))
        return True

    cpdef wait(self, uint8_t timeout):
        cdef uint64_t timeout_usec = timeout * 1000000
        check_error_code(sd_journal_wait(self.context, timeout_usec))

    def __iter__(self):
        return self.iter()

    cpdef iter(self):
        with self._lock():
            while sd_journal_next(self.context) > 0:
                yield JournalEntry(self)

    def __repr__(self):
        return "<Reader[%s]: %s>" % (self.mode.name, 'closed' if self.is_closed else 'opened')

    def __dealloc__(self):
        sd_journal_close(self.context)
