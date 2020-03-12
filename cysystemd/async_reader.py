import asyncio
from functools import partial
from uuid import UUID

from .reader import JournalOpenMode, JournalReader


class AsyncJournalReader:
    def __init__(self, loop: asyncio.AbstractEventLoop = None,
                 executor=None):

        self.__reader = JournalReader()
        self.__loop = loop or asyncio.get_event_loop()
        self.__executor = executor

    async def _exec(self, func, *args, **kwargs):
        return await self.__loop.run_in_executor(
            self.__executor, partial(func, *args, **kwargs)
        )

    async def open(self, flags=JournalOpenMode.CURRENT_USER):
        return await self._exec(self.__reader.open, flags=flags)

    async def open_directory(self, path):
        return await self._exec(self.__reader.open_directory, path)

    async def open_files(self, *file_names):
        return await self._exec(self.__reader.open_files, *file_names)

    @property
    def data_threshold(self):
        return self.__reader.data_threshold

    @data_threshold.setter
    def data_threshold(self, size):
        self.__reader.data_threshold = size

    @property
    def closed(self) -> bool:
        return self.__reader.closed

    @property
    def locked(self) -> bool:
        return self.__reader.locked

    @property
    def idle(self) -> bool:
        return self.__reader.idle

    async def seek_head(self):
        return await self._exec(self.__reader.seek_head)

    def __repr__(self):
        return "<%s[%s]: %s>" % (
            self.__class__.__name__, self.flags,
            'closed' if self.closed else 'opened'
        )

    @property
    def fd(self):
        return self.__reader.fd

    @property
    def events(self):
        return self.__reader.events

    @property
    def timeout(self):
        return self.__reader.timeout

    async def process_events(self):
        return await self._exec(self.__reader.process_events)

    async def get_catalog(self):
        return await self._exec(self.__reader.get_catalog)

    async def get_catalog_for_message_id(self, message_id):
        return await self._exec(
            self.__reader.get_catalog_for_message_id,
            message_id
        )

    async def seek_tail(self):
        return await self._exec(self.__reader.seek_tail)

    async def seek_monotonic_usec(self, boot_id: UUID, usec):
        return await self._exec(
            self.__reader.seek_monotonic_usec,
            boot_id, usec
        )

    async def seek_realtime_usec(self, usec):
        return await self._exec(self.__reader.seek_realtime_usec, usec)

    async def seek_cursor(self, cursor):
        return await self._exec(self.__reader.seek_cursor, cursor)

    def __aiter__(self):
        pass

    async def next(self, skip=0):
        pass

    async def skip_next(self, skip):
        pass

    async def previous(self, skip=0):
        pass

    async def skip_previous(self, skip):
        pass

    async def add_filter(self, rule):
        pass

    async def clear_filter(self):
        pass
