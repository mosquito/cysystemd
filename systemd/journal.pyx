import uuid
import logging
import traceback
from copy import copy
from enum import IntEnum, unique
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy


cdef extern from "<systemd/sd-journal.h>" nogil:
    int sd_journal_sendv(const iovec *iov, int n)


cdef extern from "<sys/syslog.h>" nogil:
    ctypedef struct CODE:
        char *c_name
        int c_val

    CODE prioritynames[]


cdef dict get_priorities():
    result = {}

    cdef CODE item
    cdef items = sizeof(prioritynames) / sizeof(CODE)

    for i in range(items):
        item = prioritynames[i]

        if item.c_name == NULL:
            break

        result[item.c_name.decode()] = item.c_val

    return result


cdef _priorities = get_priorities()


@unique
class Priority(IntEnum):
    PANIC = _priorities['panic']
    WARNING = _priorities['warn']
    ALERT = _priorities['alert']
    NONE = _priorities['none']
    CRITICAL = _priorities['crit']
    DEBUG = _priorities['debug']
    INFO = _priorities['info']
    ERROR = _priorities['error']
    NOTICE = _priorities['notice']


cdef extern from "sys/uio.h":
    cdef struct iovec:
        void *iov_base
        size_t iov_len


cdef send_message(dict kwargs):
    items = list(kwargs.items())

    cdef int count = len(items)
    cdef iovec* vec = <iovec *>malloc(count * sizeof(iovec))
    cdef void** cstring_list = <void **>malloc(count * sizeof(void*))

    if not vec or not cstring_list:
        raise MemoryError()

    try:
        for idx, item in enumerate(items):
            key, value = item
            msg = ("%s=%s\0" % (key.upper(), value)).encode()
            msg_len = len(msg)

            cstring_list[idx] = <char *>malloc(msg_len)
            memcpy(cstring_list[idx], <char *> msg, msg_len)

            vec[idx].iov_base = cstring_list[idx]
            vec[idx].iov_len = len(msg) - 1

        sd_journal_sendv(vec, count)

    finally:
        for i in range(count):
            free(cstring_list[i])

        free(cstring_list)
        free(vec)


def send(**kwargs):
    """ Send structued message into systemd journal """
    items = list()

    for key, value in kwargs.items():
        key = key.upper().strip()
        # The variable name must be in uppercase and consist only of characters, numbers and underscores, and may not
        # begin with an underscore.

        if key.startswith('_'):
            raise ValueError('Key name may not begin with an underscore')
        elif not key.replace("_", '').isalnum():
            raise ValueError('Key name must be consist only of characters, numbers and underscores')

        items.append((key, value))

    send_message(dict(items))


def write( message: str, priority: Priority=Priority.INFO):
    """ Write message into systemd journal """

    priority = int(Priority(int(priority)))

    send(priority=priority, message=message)


@unique
class Facility(IntEnum):
    KERN = 0
    USER = 1
    MAIL = 2
    DAEMON = 3
    AUTH = 4
    SYSLOG = 5
    LPR = 6
    NEWS = 7
    UUCP = 8
    CLOCK_DAEMON = 9
    AUTHPRIV = 10
    FTP = 11
    NTP = 12
    AUDIT = 13
    ALERT = 14
    CRON = 15
    LOCAL0 = 16
    LOCAL1 = 17
    LOCAL2 = 18
    LOCAL3 = 19
    LOCAL4 = 20
    LOCAL5 = 21
    LOCAL6 = 22
    LOCAL7 = 23


cdef to_microsecond(float ts):
    return int(ts * 1000 * 1000)


class JournaldLogHandler(logging.Handler):
    LEVELS = {
        logging.CRITICAL: Priority.CRITICAL.value,
        logging.FATAL: Priority.PANIC.value,
        logging.ERROR: Priority.ERROR.value,
        logging.WARNING: Priority.WARNING.value,
        logging.WARN: Priority.WARNING.value,
        logging.INFO: Priority.INFO.value,
        logging.DEBUG: Priority.DEBUG.value,
        logging.NOTSET: Priority.NONE.value,
    }

    __slots__ = '__facility',

    def __init__(self, facility: Facility=Facility.DAEMON):
        logging.Handler.__init__(self)
        self.__facility = Facility(int(facility))

    def emit(self, record):
        message = str(record.getMessage())

        tb_message = ''
        if record.exc_info:
            tb_message = "\n".join(traceback.format_exception(*record.exc_info))

        message += "\n"
        message += tb_message

        ts = to_microsecond(record.created)

        message_id = uuid.uuid3(
            uuid.NAMESPACE_OID,
            "$".join(
                map(
                    str,
                    (
                        message,
                        record.funcName,
                        record.levelno,
                        record.process,
                        record.processName,
                        record.levelname,
                        record.pathname,
                        record.name,
                        record.thread,
                        record.lineno,
                        ts,
                        tb_message
                    )
                )
            )
        ).hex

        data = copy(record.__dict__)
        data['priority'] = self.LEVELS[data.pop('levelno')]
        data['syslog_facility'] = self.__facility
        data['code_file'] = data.pop('filename')
        data['code_line'] = data.pop('lineno')
        data['code_func'] = data.pop('funcName')
        data['syslog_identifier'] = data['name']
        data['message'] = message
        data['message_raw'] = data.pop('msg')
        data['message_id'] = message_id
        data['code_module'] = data.pop('module')
        data['logger_name'] = data.pop('name')
        data['pid'] = data.pop('process')
        data['proccess_name'] = data.pop('processName')
        data['errno'] = 0 if not record.exc_info else 255
        data['relative_ts'] = to_microsecond(data.pop('relativeCreated'))
        data['thread_name'] = data.pop('threadName')

        for idx, item in enumerate(data.pop('args')):
            data['argument_%d' % idx] = str(item)

        if tb_message:
            data["traceback"] = tb_message

        send(**data)


__all__ = 'write', 'send', 'Priority', 'JournaldLogHandler', 'Facility'