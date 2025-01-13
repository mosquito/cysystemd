![pypi version](https://img.shields.io/pypi/v/cysystemd.svg) ![](https://img.shields.io/pypi/pyversions/cysystemd.svg)  ![License](https://img.shields.io/pypi/l/cysystemd.svg)

# systemd wrapper in Cython

Python systemd wrapper using Cython.

## Installation

### About Binary Wheels Distribution

Historically, `cysystemd` was not distributed via wheels due to systemd versioning challenges.
While the `libsystemd` headers remain relatively stable, the ABI can vary between different OS versions and
distributions.
Previous attempts to distribute wheels resulted in compatibility issues across different Linux systems.
Currently, we use the `manylinux_2_34` format for wheel distribution, which bundles the necessary shared objects
(.so files) required for operation.

This approach should provide compatibility with modern systemd installations.

**However, if you encounter any compatibility issues, we strongly recommend installing the package from
source code instead.**

```bash
pip install --no-binary=:all: cysystemd
```

### Installation from PyPI

Once the system dependencies are installed, you can install cysystemd:
```shell
pip install cysystemd
```

### Installation from Source

**You must install the systemd development headers (libsystemd) before installation!** Without these headers, the
installation will fail.

For Debian/Ubuntu users:
```shell
apt install build-essential libsystemd-dev
```

On older versions of Debian/Ubuntu, you might also need:

```shell
apt install libsystemd-daemon-dev libsystemd-journal-dev
```

For CentOS/RHEL:
```shell
yum install gcc systemd-devel
```

# BREAKING CHANGES in v2.0.0

## AsyncJournalReader Changes
1. Major refactoring of the AsyncJournalReader iterator implementation:
   * Removed internal queue and threading-based implementation
   * Now uses direct async iteration through journal events
   * More reliable handling of journal invalidation events
   * Simpler and more efficient implementation

2. `wait()` method now returns `JournalEvent` instead of boolean
   * Returns specific event type (`JournalEvent.APPEND`, `JournalEvent.INVALIDATE`, `JournalEvent.NOP`)
   * Better error handling and event processing

## Type Annotations
* Added comprehensive type hints throughout the codebase
* Added return type annotations for all public methods
* Enhanced IDE support and code documentation

## API Behavior Changes
* `seek_tail()` now automatically calls `previous()` to ensure cursor is positioned correctly
* Improved error handling and validation in various methods
* More consistent return types across the API

## Python Support
* Added support for Python 3.13
* Maintained support for Python 3.8-3.12

## Dependency Changes
* Requires latest libsystemd development headers
* Binary wheels are no longer distributed (see "Why binary wheels are no longer distributed" above)

Please ensure your code is updated to handle these changes when upgrading to version 2.0.0.

## Usage examples

### Writing to journald

#### Logging handler for python logger

```python
from cysystemd import journal
import logging
import uuid

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger()
logger.addHandler(journal.JournaldLogHandler())

try:
    logger.info("Trying to do something")
    raise Exception('foo')
except:
    logger.exception("Test Exception %s", 1)
```

#### systemd daemon notification


```python
from cysystemd.daemon import notify, Notification

# Send READY=1
notify(Notification.READY)

# Send status
notify(Notification.STATUS, "I'm fine.")

# Send stopping
notify(Notification.STOPPING)
```

Write message into systemd journal:

```python
from cysystemd import journal


journal.write("Hello Lennart")

# Or send structured data
journal.send(
    message="Hello Lennart",
    priority=journal.Priority.INFO,
    some_field='some value',
)
```

### Reading journald

#### Reading all systemd records

```python

from cysystemd.reader import JournalReader, JournalOpenMode

journal_reader = JournalReader()
journal_reader.open(JournalOpenMode.SYSTEM)
journal_reader.seek_head()

for record in journal_reader:
    print(record.data['MESSAGE'])
```

#### Read only cron logs

```python
from cysystemd.reader import JournalReader, JournalOpenMode, Rule


rules = (
  Rule("SYSLOG_IDENTIFIER", "CRON") &
  Rule("_SYSTEMD_UNIT", "crond.service") |
  Rule("_SYSTEMD_UNIT", "cron.service")
)

cron_reader = JournalReader()
cron_reader.open(JournalOpenMode.SYSTEM)
cron_reader.seek_head()
cron_reader.add_filter(rules)

for record in cron_reader:
    print(record.data['MESSAGE'])
```

#### Polling records

```python
from cysystemd.reader import JournalReader, JournalOpenMode


reader = JournalReader()
reader.open(JournalOpenMode.SYSTEM)
reader.seek_tail()

poll_timeout = 255

while True:
    reader.wait(poll_timeout)

    for record in reader:
       print(record.data['MESSAGE'])
```

#### journald open modes

* `CURRENT_USER`
* `LOCAL_ONLY`
* `RUNTIME_ONLY`
* `SYSTEM`
* `SYSTEM_ONLY` - deprecated alias of `SYSTEM`


```python
from cysystemd.reader import JournalReader, JournalOpenMode


reader = JournalReader()
reader.open(JournalOpenMode.CURRENT_USER)
```

#### journald entry

JournalEntry class has some special properties and methods:

* `data` - journal entry content (`dict`)
* `date` - entry timestamp (`datetime` instance)
* `cursor` - systemd identification bytes for this entry
* `boot_id()` - returns bootid
* `get_realtime_sec()` - entry epoch (`float`)
* `get_realtime_usec()` - entry epoch (`int` microseconds)
* `get_monotonic_sec()` - entry monotonic time (`float`)
* `get_monotonic_usec()` - entry monotonic time (`int` microseconds)
* `__getitem__(key)` - shoutcut for `entry.data[key]`


#### journald reader

JournalReader class has some special properties and methods:

* `open(flags=JournalOpenMode.CURRENT_USER)` - opening journald
  with selected mode
* `open_directory(path)` - opening journald from path
* `open_files(*filename)` - opening journald from files
* `data_threshold` - may be used to get or set the data field size threshold
  for data returned by fething entry data.
* `closed` - returns True when journal reader closed
* `locked` - returns True when journal reader locked
* `idle` - returns True when journal reader opened
* `seek_head` - move reader pointer to the first entry
* `seek_tail` - move reader pointer to the last entry
* `seek_monotonic_usec` - seeks to the entry with the specified monotonic
  timestamp, i.e. CLOCK_MONOTONIC. Since monotonic time restarts on every
  reboot a boot ID needs to be specified as well.
* `seek_realtime_usec` - seeks to the entry with the specified realtime
  (wallclock) timestamp, i.e. CLOCK_REALTIME. Note that the realtime clock
  is not necessarily monotonic. If a realtime timestamp is ambiguous, it is
  not defined which position is sought to.
* `seek_cursor` - seeks to the entry located at the specified cursor
  (see `JournalEntry.cursor`).
* `wait(timeout)` - It will synchronously wait until the journal gets
  changed. The maximum time this call sleeps may be controlled with the
  timeout_usec parameter.
* `__iter__` - returns JournalReader object
* `__next__` - calls `next()` or raise `StopIteration`
* `next(skip=0)` - returns the next `JournalEntry`. The `skip`
  parameter skips some entries.
* `previous(skip=0)` - returns the previous `JournalEntry`.
  The `skip` parameter skips some entries.
* `skip_next(skip)` - skips next entries.
* `skip_previous(skip)` - skips next entries.
* `add_filter(rule)` - adding filter rule.
  See `read-only-cron-logs`_ as example.
* `clear_filter` - reset all filters
* `fd` - returns a special file descriptor
* `events` - returns `EPOLL` events
* `timeout` - returns internal timeout
* `process_events()` - After each poll() wake-up process_events() needs
  to be called to process events. This call will also indicate what kind of
  change has been detected.
* `get_catalog()` - retrieves a message catalog entry for the current
  journal entry. This will look up an entry in the message catalog by using
  the "MESSAGE_ID=" field of the current journal entry. Before returning
  the entry all journal field names in the catalog entry text enclosed in
  "@" will be replaced by the respective field values of the current entry.
  If a field name referenced in the message catalog entry does not exist,
  in the current journal entry, the "@" will be removed, but the field name
  otherwise left untouched.
* `get_catalog_for_message_id(message_id: UUID)` - works similar to
  `get_catalog()` but the entry is looked up by the specified
  message ID (no open journal context is necessary for this),
  and no field substitution is performed.


### Asyncio support

Initial `asyncio` support for reading journal asynchronously.

#### AsyncJournalReader

Blocking methods were wrapped by threads.
Method `wait()` use epoll on journald file descriptor.

```python
import asyncio
import json

from cysystemd.reader import JournalOpenMode
from cysystemd.async_reader import AsyncJournalReader


async def main():
    reader = AsyncJournalReader()
    await reader.open(JournalOpenMode.SYSTEM)
    await reader.seek_tail()

    async for record in reader:
        print(json.dumps(record.data, indent=1, sort_keys=True))

if __name__ == '__main__':
    asyncio.run(main())
```
