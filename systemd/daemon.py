import logging
from enum import Enum, unique
from collections import namedtuple
from ._daemon import sd_notify


log = logging.getLogger('systemd.daemon')


NotificationValue = namedtuple("NotificationValue", ("name", "constant", "type"))


@unique
class Notification(Enum):
    READY = NotificationValue(name='READY', constant=1, type=int)
    RELOADING = NotificationValue(name='RELOADING', constant=1, type=int)
    STOPPING = NotificationValue(name='STOPPING', constant=1, type=int)
    STATUS = NotificationValue(name='STATUS', constant=None, type=str)
    ERRNO = NotificationValue(name='ERRNO', constant=None, type=int)
    BUSERROR = NotificationValue(name='BUSERROR', constant=None, type=str)
    MAINPID = NotificationValue(name='MAINPID', constant=None, type=int)
    WATCHDOG = NotificationValue(name='WATCHDOG', constant=1, type=int)
    FDSTORE = NotificationValue(name='FDSTORE', constant=1, type=int)
    FDNAME = NotificationValue(name='FDNAME', constant=None, type=int)
    WATCHDOG_USEC = NotificationValue(name='WATCHDOG_USEC', constant=None, type=int)


def notify(notification: Notification, value: int=None, unset_environment: bool=False):
    """ Send notification to systemd daemon

    :type notification: Notification
    :param notification: Notification instance
    :param value: str or int value for non constant notifications
    :returns None
    """

    if not isinstance(notification, Notification):
        raise TypeError("state must be an instance of Notigication")

    state = notification.value

    if state.constant is not None and value:
        raise ValueError(
            "State %s should contain only constant value %r" % (state.name, state.constant),
            state.name, state.constant
        )

    line = "%s=%s" % (
        state.name,
        state.constant if state.constant is not None else state.type(value)
    )

    log.debug("Send %r into systemd", line)

    try:
        return sd_notify(line, unset_environment)
    except Exception as e:
        log.error("%s", e)


__all__ = ('notify', 'Notification')
