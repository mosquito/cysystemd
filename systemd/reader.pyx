#cython: unraisable_tracebacks=True

from libc.stdlib cimport malloc, free
from cpython cimport dict

from sd_journal cimport *
from libc.stdint cimport uint64_t, uint8_t
from sd_id128 cimport sd_id128_t

import os
from datetime import datetime, timezone
from uuid import UUID
from contextlib import contextmanager
from errno import errorcode
from enum import IntEnum
from string import ascii_letters


try:
    from types import MappingProxyType as dictproxy
except ImportError:
    from dictproxyhack import dictproxy


cdef extern from "<poll.h>":
    cdef const int POLLIN
    cdef const int POLLOUT


EV_POLLIN = POLLIN
EV_POLLOUT = POLLOUT


cdef enum MATHCER_OPERATION:
    MATHCER_OPERATION_AND,
    MATHCER_OPERATION_OR,


cdef class Matcher:
    cdef list chain

    def __init__(self):
        self.chain = []

    def and_(self, str key, str value):
        self.chain.append((MATHCER_OPERATION_AND, Operation(key, value)))
        return self

    def or_(self, str key, str value):
        self.chain.append((MATHCER_OPERATION_OR, Operation(key, value)))
        return self

    def __repr__(self):
        return "Matcher({0!r})".format(self.chain)


cdef class Operation:
    cdef bytes __expression

    def __repr__(self):
        return "%r" % self.expression.decode()

    def __cinit__(self, str key, str value):
        if key[0] not in ascii_letters:
            raise ValueError("Key must be start from ascii-letter")

        cdef str exp = "=".join((key.upper(), value))
        cdef bytes bexp

        if '\0' in exp:
            raise ValueError("Expression must not contain \ 0 character")

        self.__expression = exp.encode()

    @property
    def expression(self):
        return self.__expression


def check_error_code(int code):
    if code >= 0:
        return code

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

    def __cinit__(self, JournalReader reader):
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
                if not isinstance(self.__data[key], list):
                    self.__data[key] = [self.__data[key]]
                self.__data[key].append(value)
            else:
                self.__data[key] = value

        self._data = dictproxy(self.__data)
        self.__boot_uuid = UUID(bytes=self.__boot_id.bytes[:16])
        date = datetime.utcfromtimestamp(self.get_realtime_sec())
        date.replace(tzinfo=timezone.utc)
        self.__date = date

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


cdef class JournalReader:
    cdef sd_journal* context
    cdef char state
    cdef object flags

    def __init__(self):
        self.state = READER_NULL
        self.flags = None

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
        cdef int rcode

        with nogil:
            rcode = sd_journal_get_data_threshold(self.context, &result)

        check_error_code(rcode)
        return result

    @data_threshold.setter
    def data_threshold(self, size):
        cdef size_t sz = size
        cdef int result

        with nogil:
            result = sd_journal_set_data_threshold(self.context, sz)

        check_error_code(result)

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

    def seek_head(self):
        cdef int result

        with nogil:
            result = sd_journal_seek_head(self.context)

        check_error_code(result)

        return True

    def seek_tail(self):
        cdef int result

        with nogil:
            result = sd_journal_seek_tail(self.context)

        check_error_code(result)
        return True

    def seek_monotonic_usec(self, boot_id: UUID, uint64_t usec):
        cdef sd_id128_t cboot_id
        cdef int result

        cboot_id.bytes = boot_id.bytes
        with nogil:
            result = sd_journal_seek_monotonic_usec(self.context, cboot_id, usec)

        check_error_code(result)
        return True

    def seek_realtime_usec(self, uint64_t usec):
        cdef uint64_t cusec = usec
        cdef int result

        with nogil:
            result = sd_journal_seek_realtime_usec(self.context, cusec)

        check_error_code(result)
        return True

    def seek_cursor(self, bytes cursor):
        cdef char* ccursor = cursor
        cdef int result

        with nogil:
            result = sd_journal_seek_cursor(self.context, ccursor)

        check_error_code(result)
        return True

    cpdef wait(self, uint8_t timeout):
        cdef uint64_t timeout_usec = timeout * 1000000
        cdef int result

        with nogil:
            result = sd_journal_wait(self.context, timeout_usec)

        check_error_code(result)

    def __iter__(self):
        return self

    def __next__(self):
        result = self.next()
        if result is None:
            raise StopIteration
        return result

    def next(self):
        cdef int result

        with nogil:
            result = sd_journal_next(self.context)

        check_error_code(result)

        if result > 0:
            return JournalEntry(self)
        else:
            return None

    def skip_next(self, uint64_t skip):
        cdef int result

        with nogil:
            result = sd_journal_next_skip(self.context, skip)

        check_error_code(result)

    def previous(self, uint64_t skip=0):
        cdef int result

        with nogil:
            if skip:
                result = sd_journal_previous_skip(self.context, skip)
            else:
                result = sd_journal_previous(self.context)


        check_error_code(result)

        if skip:
            return None

        if result > 0:
            return JournalEntry(self)
        else:
            return None

    def skip_previous(self, uint64_t skip):
        cdef int result

        with nogil:
            result = sd_journal_previous_skip(self.context, skip)

        check_error_code(result)

    def add_filter(self, Matcher matcher):
        cdef int result
        cdef char* exp

        for operation_code, operation in matcher.chain:
            exp = operation.expression

            if operation_code == MATHCER_OPERATION_OR:
                result = sd_journal_add_disjunction(self.context)
                check_error_code(result)
            result = sd_journal_add_match(self.context, exp, 0)
            check_error_code(result)

    def clear_filter(self):
        with nogil:
            sd_journal_flush_matches(self.context)

    def __repr__(self):
        return "<Reader[%s]: %s>" % (self.flags, 'closed' if self.closed else 'opened')

    def __dealloc__(self):
        sd_journal_close(self.context)

    @property
    def fd(self):
        cdef int result

        with nogil:
            result = sd_journal_get_fd(self.context)

        return check_error_code(result)

    @property
    def events(self):
        cdef int result

        with nogil:
            result = sd_journal_get_events(self.context)

        return check_error_code(result)

    @property
    def timeout(self):
        cdef int result
        cdef uint64_t timeout

        with nogil:
            result = sd_journal_get_timeout(self.context, &timeout)

        check_error_code(result)
        return timeout

    def process_events(self):
        cdef int result

        with nogil:
            result = sd_journal_process(self.context)

        check_error_code(result)

    def get_catalog(self):
        cdef int result
        cdef char* catalog
        cdef bytes bcatalog

        with nogil:
            result = sd_journal_get_catalog(self.context, &catalog)

        length = check_error_code(result)
        bcatalog = catalog[:length]

        return bcatalog

    def get_catalog_for_message_id(self, message_id):
        cdef int result
        cdef char* catalog
        cdef bytes bcatalog
        cdef sd_id128_t id128

        id128.bytes = message_id.bytes

        with nogil:
            result = sd_journal_get_catalog_for_message_id(id128, &catalog)

        length = check_error_code(result)
        bcatalog = catalog[:length]

        return bcatalog
