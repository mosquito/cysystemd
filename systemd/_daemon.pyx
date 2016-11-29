cimport sd_daemon


def sd_notify(line: str, unset_environment: bool=False) -> int:
    """ Send notification to systemd daemon

    :type notification: Notification
    :param notification: Notification instance
    :param value: str or int value for non constant notifications
    :returns None
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
