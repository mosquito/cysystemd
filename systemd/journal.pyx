from enum import IntEnum, unique
from libc.stdlib cimport malloc, free


cdef extern from "sys/uio.h":
    cdef struct iovec:
        void *iov_base
        size_t iov_len


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


cdef send_message(dict kwargs):
    items = list(kwargs.items())

    cdef int count = len(items)
    cdef iovec* vec = <iovec *>malloc(count * sizeof(iovec))

    if not vec:
        raise MemoryError()

    try:
        for idx, item in enumerate(items):
            key, value = item
            msg = "%s=%s" % (str(key), str(value))
            msg = msg.encode()
            s = <char*> msg
            vec[idx].iov_base = s
            vec[idx].iov_len = len(msg)

        sd_journal_sendv(vec, count)

    finally:
        free(vec)


def send(dict data):
    """ Send structued message into systemd journal """

    send_message(data)


def write( message: str, priority: Priority=Priority.INFO):
    """ Write message into systemd journal """

    if not isinstance(priority, Priority):
        raise TypeError("priority argument must be Priority instance")

    send({'PRIORITY': int(priority), 'MESSAGE': str(message)})


__all__ = 'write', 'send', 'Priority'