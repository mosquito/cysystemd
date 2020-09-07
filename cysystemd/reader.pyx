#cython: unraisable_tracebacks=True

from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.stdint cimport uint64_t, uint8_t, uint32_t
from cpython cimport dict

from sd_journal cimport *
from sd_id128 cimport sd_id128_t

import os
import logging
from datetime import datetime, timezone
from uuid import UUID
from contextlib import contextmanager
from errno import errorcode
from enum import IntEnum


log = logging.getLogger(__name__)


WAIT_MAX_TIME = 4294967295


class JournalEvent(IntEnum):
    NOP = SD_JOURNAL_NOP
    APPEND = SD_JOURNAL_APPEND
    INVALIDATE =  SD_JOURNAL_INVALIDATE


cdef enum MATHCER_OPERATION:
    MATHCER_OPERATION_CONJUNCTION,
    MATHCER_OPERATION_DISJUNCTION,


class MatchOperation(IntEnum):
    AND = MATHCER_OPERATION_CONJUNCTION
    NOR = MATHCER_OPERATION_DISJUNCTION


cdef extern from "<poll.h>":
    cdef const int POLLIN
    cdef const int POLLOUT


class Poll(IntEnum):
    IN = POLLIN
    OUT = POLLOUT


cdef class Rule:
    cdef object _expression
    cdef object _child
    cdef object _root
    cdef object _operand

    def __init__(self, str key, str value):
        cdef str exp = "=".join((key.upper(), value))

        if '\0' in exp:
            raise ValueError("Expression must not contains \\0 character")

        self._expression = exp.encode()
        self._child = None
        self._root = self
        self._operand = MatchOperation.AND

    @property
    def expression(self):
        return self._expression

    @property
    def child(self):
        return self._child

    @child.setter
    def child(self, Rule child):
        self._child = child

    @property
    def root(self):
        return self._root

    @root.setter
    def root(self, Rule root):
        self._root = root

    @property
    def operand(self):
        return self._operand

    @operand.setter
    def operand(self, uint8_t op):
        self._operand = MatchOperation(op)

    def __and__(self, Rule other):
        self.operand = MatchOperation.AND
        self.child = other
        other.root = self.root

        return other

    def __or__(self, Rule other):
        self.operand = MatchOperation.OR
        self.child = other
        other.root = self.root

        return other

    def __repr__(self):
        ret = []
        for opcode, exp in self:
            ret.append("%r" % exp.decode())
            ret.append(opcode.name)

        return 'Rule(%r)' % ' '.join(ret[:-1])

    def __iter__(self):
        rule = self.root

        while rule is not None:
            yield rule.operand, rule.expression
            rule = rule.child


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

    max_message_size = 2**20

    def __cinit__(self, JournalReader reader):
        cdef const void *data
        cdef size_t length = 0

        self.__data = {}
        check_error_code(sd_journal_get_realtime_usec(reader.context, &self.realtime_usec))
        check_error_code(sd_journal_get_monotonic_usec(reader.context, &self.monotonic_usec, &self.__boot_id))
        check_error_code(sd_journal_get_cursor(reader.context, &self.cursor))

        sd_journal_restart_data(reader.context)

        while True:

            length = 0

            result = sd_journal_enumerate_data(reader.context, <const void **>&data, &length)

            if result == 0 or length == 0:
                break

            if length > self.max_message_size:
                log.warning("got message with enormous length %d", length)
                break

            value = bytes((<char*> data)[:length]).decode(errors='replace')
            if '=' not in value:
                log.warning("got unexpected %r from sd_journal_enumerate_data", value)
                break
            key, value = value.split("=", 1)

            if key in self.__data:
                if not isinstance(self.__data[key], list):
                    self.__data[key] = [self.__data[key]]
                self.__data[key].append(value)
            else:
                self.__data[key] = value

        self._data = self.__data
        self.__boot_uuid = UUID(bytes=self.__boot_id.bytes[:16])
        date = datetime.utcfromtimestamp(self.get_realtime_sec())
        date.replace(tzinfo=timezone.utc)
        self.__date = date

    @property
    def cursor(self):
        return self.cursor

    cpdef float get_realtime_sec(self):
        return self.realtime_usec / 1000000

    cpdef float get_monotonic_sec(self):
        return self.monotonic_usec / 1000000

    cpdef uint64_t get_realtime_usec(self):
        return self.realtime_usec

    cpdef uint64_t get_monotonic_usec(self):
        return self.monotonic_usec

    def boot_id(self):
        return self.boot_id

    @property
    def date(self):
        return self.__date

    @property
    def data(self):
        return self._data

    def __dealloc__(self):
        PyMem_Free(self.cursor)

    def __repr__(self):
        return "<JournalEntry: %r>" % self.date

    def __getitem__(self, str key):
        return self._data[key]


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

        cdef char **paths = <char **>PyMem_Malloc(len(file_names) * sizeof(char*))

        for i, s in enumerate(file_names):
            cstr = s.encode()
            paths[i] = cstr

        try:
            with self._lock(opening=True):
                check_error_code(sd_journal_open_files(&self.context, paths, 0))
        finally:
            PyMem_Free(paths)

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

        with self._lock():
            result = sd_journal_seek_head(self.context)

        check_error_code(result)

        return True

    def seek_tail(self):
        cdef int result

        with self._lock():
            result = sd_journal_seek_tail(self.context)

        check_error_code(result)
        return True

    def seek_monotonic_usec(self, boot_id: UUID, uint64_t usec):
        cdef sd_id128_t cboot_id
        cdef int result

        cboot_id.bytes = boot_id.bytes

        with self._lock():
            result = sd_journal_seek_monotonic_usec(self.context, cboot_id, usec)

        check_error_code(result)
        return True

    def seek_realtime_usec(self, uint64_t usec):
        cdef uint64_t cusec = usec
        cdef int result

        with self._lock():
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

    cpdef wait(self, uint32_t timeout = WAIT_MAX_TIME):
        cdef uint64_t timeout_usec = timeout * 1000000
        cdef int result

        with self._lock():
            with nogil:
                result = sd_journal_wait(self.context, timeout_usec)

        return JournalEvent(check_error_code(result))

    def __iter__(self):
        return self

    def __next__(self):
        result = self.next()
        if result is None:
            raise StopIteration
        return result

    def next(self, uint64_t skip=0):
        cdef int result

        with self._lock():
            if skip:
                result = sd_journal_next_skip(self.context, skip)
            else:
                result = sd_journal_next(self.context)

            if check_error_code(result) > 0:
                return JournalEntry(self)

    def skip_next(self, uint64_t skip):
        cdef int result

        with self._lock():
            result = sd_journal_next_skip(self.context, skip)

        return check_error_code(result)

    def previous(self, uint64_t skip=0):
        cdef int result

        with self._lock():
            if skip:
                result = sd_journal_previous_skip(self.context, skip)
            else:
                result = sd_journal_previous(self.context)

            if check_error_code(result) > 0:
                return JournalEntry(self)

    def skip_previous(self, uint64_t skip):
        cdef int result

        with self._lock():
            result = sd_journal_previous_skip(self.context, skip)

        return check_error_code(result)

    def add_filter(self, Rule rule):
        cdef int result
        cdef char* exp

        with self._lock():
            for operand, exp in rule:
                result = sd_journal_add_match(self.context, exp, 0)
                check_error_code(result)

                if operand == MatchOperation.NOR:
                    result = sd_journal_add_disjunction(self.context)
                    return check_error_code(result)

                elif operand == MatchOperation.AND:
                    result = sd_journal_add_conjunction(self.context)
                    return check_error_code(result)

                raise ValueError('Invalid operation')

    def clear_filter(self):
        sd_journal_flush_matches(self.context)

    def __repr__(self):
        return "<Reader[%s]: %s>" % (
            self.flags, 'closed' if self.closed else 'opened'
        )

    def __dealloc__(self):
        sd_journal_close(self.context)

    @property
    def fd(self):
        return check_error_code(sd_journal_get_fd(self.context))

    @property
    def events(self):
        return Poll(check_error_code(sd_journal_get_events(self.context)))

    @property
    def timeout(self):
        cdef uint64_t timeout
        check_error_code(sd_journal_get_timeout(self.context, &timeout))
        return timeout

    def process_events(self):
        return JournalEvent(check_error_code(sd_journal_process(self.context)))

    def get_catalog(self):
        cdef int result
        cdef char* catalog
        cdef bytes bcatalog

        result = sd_journal_get_catalog(self.context, &catalog)

        length = check_error_code(result)
        bcatalog = catalog[:length]
        PyMem_Free(catalog)

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
        PyMem_Free(catalog)

        return bcatalog
