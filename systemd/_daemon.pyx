cimport sd_daemon


def sd_notify(line, unset_environment=False):
    """ Send notification to systemd daemon

    :type line: str
    :type: unset_environment: bool
    :return: int
    :raises RuntimeError: When c-call returns zero
    :raises ValueError: Otherwise
    """

    line = line.encode()

    cdef int unset_env
    unset_env = 2 if unset_environment else 0

    result = sd_daemon.sd_notify(unset_env, line)

    if result > 0:
        return result
    elif result == 0:
        raise RuntimeError("Data could not be sent")
    else:
        raise ValueError("Notification error #%d" % result, result)
