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
