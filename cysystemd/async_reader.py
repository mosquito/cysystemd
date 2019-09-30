import asyncio
from uuid import UUID

from .reader import JournalOpenMode


class AsyncJournalReader:
    def __init__(self):
        pass

    def open(self, flags=JournalOpenMode.CURRENT_USER):
        pass

    def open_directory(self, path):
        pass

    def open_files(self, *file_names):
        pass

    @property
    def data_threshold(self):
        return None

    @data_threshold.setter
    def data_threshold(self, size):
        pass

    @property
    def closed(self):
        return None

    @property
    def locked(self):
        pass

    @property
    def idle(self):
        pass

    def seek_head(self):
        pass

        return True

    def seek_tail(self):
        pass

    def seek_monotonic_usec(self, boot_id: UUID, usec):
        pass

    def seek_realtime_usec(self, usec):
        pass

    def seek_cursor(self, cursor):
        pass

    def __aiter__(self):
        pass

    def next(self, skip=0):
        pass

    def skip_next(self, skip):
        pass

    def previous(self, skip=0):
        pass

    def skip_previous(self, skip):
        pass

    def add_filter(self, rule):
        pass

    def clear_filter(self):
        pass

    def __repr__(self):
        return "<%s[%s]: %s>" % (
            self.__class__.__name__, self.flags,
            'closed' if self.closed else 'opened'
        )

    @property
    def fd(self):
        pass

    @property
    def events(self):
        pass

    @property
    def timeout(self):
        pass

    def process_events(self):
        pass

    def get_catalog(self):
        pass

    def get_catalog_for_message_id(self, message_id):
        pass
