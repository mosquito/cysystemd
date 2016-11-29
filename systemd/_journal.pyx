from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from sd_journal cimport sd_journal_sendv, prioritynames, CODE, iovec


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

        return sd_journal_sendv(vec, count)
    finally:
        for i in range(count):
            free(cstring_list[i])

        free(cstring_list)
        free(vec)


def syslog_priorities():
    return get_priorities()


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

    return send_message(dict(items))


__all__ = 'send', 'Priority', 'Facility'