import asyncio
import logging
import threading
from collections import deque

from collections.abc import AsyncIterator
from functools import partial
from typing import Callable, TypeVar
from uuid import UUID
from weakref import finalize

from .reader import JournalOpenMode, JournalReader, JournalEntry

A = TypeVar("A")
R = TypeVar("R")
log = logging.getLogger("cysystemd.async_reader")


class Base:
    def __init__(self, loop=None, executor=None):
        self._executor = executor
        self._loop = loop or asyncio.get_event_loop()

    async def _exec(self, func: Callable[[A], R], *args, **kwargs) -> R:
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
        self.__iterator = None

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

    def __aiter__(self) -> "AsyncReaderIterator":
        if self.__iterator is not None:
            self.__iterator.close()
            self.__iterator = None

        iterator = AsyncReaderIterator(
            loop=self._loop, executor=self._executor, reader=self.__reader
        )

        finalize(self, iterator.close)

        self.__iterator = iterator
        return iterator


class AsyncReaderIterator(Base, AsyncIterator):
    __slots__ = "reader", "queue", "queue_full", "event", "lock", "closed"

    QUEUE_SIZE = 2
    WRITE_EVENT_WAIT_TIME = 0.1

    def __init__(self, *, reader, loop, executor):
        super().__init__(loop=loop, executor=executor)
        self.reader = reader
        self.lock = asyncio.Lock()
        self.queue = deque()
        self.read_event = asyncio.Event()
        self.write_event = threading.Semaphore(self.QUEUE_SIZE)
        self.close_event = threading.Event()

        self._loop.create_task(self._exec(self._journal_reader))

    def close(self):
        self.close_event.set()
        self.__set_read_event()

    def __del__(self):
        self.close()

    def __set_read_event(self):
        if self._loop.is_closed():
            return

        self._loop.call_soon_threadsafe(self.read_event.set)

    def _journal_reader(self):
        try:
            for item in self.reader:
                while not self.close_event.is_set():
                    if self.write_event.acquire(
                        timeout=self.WRITE_EVENT_WAIT_TIME
                    ):
                        break
                else:
                    return

                self.queue.append(item)
                self.__set_read_event()
        finally:
            self.close()

    async def __anext__(self) -> JournalEntry:
        async with self.lock:
            if self.close_event.is_set() and len(self.queue) == 0:
                raise StopAsyncIteration

            while True:
                try:
                    item = self.queue.popleft()
                except IndexError:
                    await self.read_event.wait()
                    self.read_event.clear()
                    continue
                else:
                    self.write_event.release()

                return item
