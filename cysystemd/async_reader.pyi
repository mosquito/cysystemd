import asyncio
import threading
from collections import AsyncIterator, deque
from concurrent.futures import Executor
from typing import Coroutine, Any, Optional, Union
from uuid import UUID

from cysystemd.reader import (
    JournalEntry,
    JournalOpenMode,
    JournalReader,
    Poll,
    Rule,
)


class Base:
    _loop: Optional[asyncio.AbstractEventLoop]
    _executor: Optional[Executor]

    def __init__(self, loop: asyncio.AbstractEventLoop = None,
                 executor: Optional[Executor] = None): ...

    async def _exec(
        self, func, *args, **kwargs
    ) -> Coroutine[Any, Any, Any]: ...


class AsyncJournalReader(Base):
    __reader: JournalReader
    __wait_lock: asyncio.Lock
    __flags: Optional[JournalOpenMode]
    __iterator: Optional["AsyncReaderIterator"]

    async def wait(self) -> bool: ...

    def open(
        self, flags: JournalOpenMode = JournalOpenMode.CURRENT_USER
    ) -> Coroutine[Any, Any, None]: ...

    def open_directory(self, path) -> Coroutine[Any, Any, None]: ...

    def open_files(self, *file_names) -> Coroutine[Any, Any, None]: ...

    @property
    def data_threshold(self) -> int: ...

    @data_threshold.setter
    def data_threshold(self, size: int): ...

    @property
    def closed(self) -> bool: ...

    @property
    def locked(self) -> bool: ...

    @property
    def idle(self) -> bool: ...

    def seek_head(self) -> Coroutine[Any, Any, bool]: ...

    def __repr__(self) -> str: ...

    @property
    def fd(self) -> int: ...

    @property
    def events(self) -> Poll: ...

    @property
    def timeout(self) -> int: ...

    def get_catalog(self) -> Coroutine[Any, Any, bytes]: ...

    def get_catalog_for_message_id(
        self, message_id: UUID
    ) -> Coroutine[Any, Any, bytes]: ...

    def seek_tail(self) -> Coroutine[Any, Any, bool]: ...

    def seek_monotonic_usec(self, boot_id: UUID, usec: int) -> Coroutine[Any, Any, bool]: ...

    def seek_realtime_usec(self, usec: int) -> Coroutine[Any, Any, bool]: ...

    def seek_cursor(self, cursor) -> Coroutine[Any, Any, bool]: ...

    def skip_next(self, skip: int) -> Coroutine[Any, Any, int]: ...

    def skip_previous(self, skip) -> Coroutine[Any, Any, int]: ...

    def next(self, skip: int = 0) -> Coroutine[Any, Any, JournalEntry]: ...

    def previous(self, skip: int = 0) -> Coroutine[Any, Any, JournalEntry]: ...

    def add_filter(self, rule: Rule) -> Coroutine[Any, Any, int]: ...

    def clear_filter(self) -> Coroutine[Any, Any, None]: ...

    def __aiter__(self) -> AsyncReaderIterator: ...


class AsyncReaderIterator(Base, AsyncIterator):
    QUEUE_SIZE: int = 1024
    WRITE_EVENT_WAIT_TIME: Union[float, int] = 0.1
    reader: JournalReader
    queue: deque
    lock: asyncio.Lock
    read_event: asyncio.Event
    write_event: threading.Event
    close_event: threading.Event

    # noinspection PyMissingConstructor
    def __init__(self, *, reader: JournalReader,
                 loop: asyncio.AbstractEventLoop, executor: Optional[Executor]): ...

    def _journal_reader(self) -> None: ...

    def close(self) -> None: ...

    async def __anext__(self) -> JournalEntry: ...
