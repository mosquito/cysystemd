import asyncio
import logging
from collections.abc import AsyncIterator
from functools import partial
from queue import Empty as QueueEmpty
from uuid import UUID

from .reader import JournalEntry, JournalOpenMode, JournalReader


try:
    from queue import SimpleQueue
except ImportError:
    from queue import Queue as SimpleQueue


log = logging.getLogger("cysystemd.async_reader")


class Base:
    def __init__(self, loop=None, executor=None):
        self._executor = executor
        self._loop = loop or asyncio.get_event_loop()

    async def _exec(self, func, *args, **kwargs):
        # noinspection PyTypeChecker
        return await self._loop.run_in_executor(
            self._executor, partial(func, *args, **kwargs)
        )


class AsyncJournalReader(Base):
    def __init__(self, executor=None, loop=None):
        super().__init__(loop=loop, executor=executor)
        self.__reader = JournalReader()
        self.__flags = None
        self.__wait_lock = asyncio.Lock()

    async def wait(self):
        async with self.__wait_lock:
            loop = self._loop
            reader = self.__reader
            event = asyncio.Event()

            loop.add_reader(reader.fd, event.set)

            try:
                await event.wait()
            finally:
                loop.remove_reader(reader.fd)

            reader.process_events()

        return True

    def open(self, flags=JournalOpenMode.CURRENT_USER):
        self.__flags = flags
        return self._exec(self.__reader.open, flags=flags)

    def open_directory(self, path):
        return self._exec(self.__reader.open_directory, path)

    def open_files(self, *file_names):
        return self._exec(self.__reader.open_files, *file_names)

    @property
    def data_threshold(self):
        return self.__reader.data_threshold

    @data_threshold.setter
    def data_threshold(self, size):
        self.__reader.data_threshold = size

    @property
    def closed(self):
        return self.__reader.closed

    @property
    def locked(self):
        return self.__reader.locked

    @property
    def idle(self):
        return self.__reader.idle

    def seek_head(self):
        return self._exec(self.__reader.seek_head)

    def __repr__(self):
        return "<%s[%s]: %s>" % (
            self.__class__.__name__,
            self.__flags,
            "closed" if self.closed else "opened",
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

    def get_catalog(self):
        return self._exec(self.__reader.get_catalog)

    def get_catalog_for_message_id(self, message_id):
        return self._exec(
            self.__reader.get_catalog_for_message_id, message_id
        )

    def seek_tail(self):
        return self._exec(self.__reader.seek_tail)

    def seek_monotonic_usec(self, boot_id: UUID, usec):
        return self._exec(
            self.__reader.seek_monotonic_usec, boot_id, usec
        )

    def seek_realtime_usec(self, usec):
        return self._exec(self.__reader.seek_realtime_usec, usec)

    def seek_cursor(self, cursor):
        return self._exec(self.__reader.seek_cursor, cursor)

    def skip_next(self, skip):
        return self._exec(self.__reader.skip_next, skip)

    def previous(self, skip=0):
        return self._exec(self.__reader.previous, skip)

    def skip_previous(self, skip):
        return self._exec(self.__reader.skip_previous, skip)

    def add_filter(self, rule):
        return self._exec(self.__reader.add_filter, rule)

    def clear_filter(self):
        return self._exec(self.__reader.clear_filter)

    def next(self, skip=0):
        return self._exec(self.__reader.next, skip)

    def __aiter__(self):
        return AsyncReaderIterator(
            loop=self._loop, executor=self._executor, reader=self.__reader
        )


class AsyncReaderIterator(Base, AsyncIterator):
    __slots__ = "reader", "queue", "event", "lock", "closed"

    QUEUE_SIZE = 1024

    def __init__(self, *, reader, loop, executor):
        super().__init__(loop=loop, executor=executor)
        self.reader = reader
        self.queue = SimpleQueue()
        self.event = asyncio.Event()
        self.lock = asyncio.Lock()
        self.closed = False

        self._loop.create_task(self._exec(self._reader))

    def _reader(self):
        for item in self.reader:
            self.queue.put(item)
            self._loop.call_soon_threadsafe(self.event.set)

        self._loop.call_soon_threadsafe(self.event.set)
        self.closed = True

    async def __anext__(self):
        if self.closed:
            raise StopAsyncIteration

        async with self.lock:
            while True:
                try:
                    return self.queue.get_nowait()
                except QueueEmpty:
                    await self.event.wait()
                    self.event.clear()
