SystemD wrapper in Cython
=========================

.. image:: https://img.shields.io/pypi/v/cysystemd.svg
    :target: https://pypi.python.org/pypi/cysystemd/
    :alt: Latest Version

.. image:: https://img.shields.io/pypi/wheel/cysystemd.svg
    :target: https://pypi.python.org/pypi/cysystemd/

.. image:: https://img.shields.io/pypi/pyversions/cysystemd.svg
    :target: https://pypi.python.org/pypi/cysystemd/

.. image:: https://img.shields.io/pypi/l/cysystemd.svg
    :target: https://pypi.python.org/pypi/cysystemd/


Python systemd wrapper using Cython


.. contents:: Table of contents


Installation
------------

All packages available on
`github releases <https://github.com/mosquito/cysystemd/releases>`_.


Debian/Ubuntu
+++++++++++++

Install repository key

.. code-block:: bash

   wget -qO - 'https://bintray.com/user/downloadSubjectPublicKey?username=bintray' | \
      apt-key add -


Install the repository file

Debian Jessie:

.. code-block:: bash

   echo "deb http://dl.bintray.com/mosquito/cysystemd jessie main" > /etc/apt/sources.list.d/cysystemd.list
   apt-get update
   apt-get install python-cysystemd python3-cysystemd

Ubuntu Xenial:

.. code-block:: bash

   echo "deb http://dl.bintray.com/mosquito/cysystemd xenial main" > /etc/apt/sources.list.d/cysystemd.list
   apt-get update
   apt-get install python-cysystemd python3-cysystemd

Ubuntu Bionic:

.. code-block:: bash

   echo "deb http://dl.bintray.com/mosquito/cysystemd bionic main" > /etc/apt/sources.list.d/cysystemd.list
   apt-get update
   apt-get install python-cysystemd python3-cysystemd


Centos 7
++++++++

.. code-block:: bash

   yum localinstall \
      https://github.com/mosquito/cysystemd/releases/download/0.17.1/python-cysystemd-0.17.1-1.centos7.x86_64.rpm


Installation from sources
+++++++++++++++++++++++++

You should install systemd headers

For debian users:


.. code-block:: bash

    apt-get install build-essential \
        libsystemd-journal-dev \
        libsystemd-daemon-dev \
        libsystemd-dev


For CentOS/RHEL

.. code-block:: bash

    yum install gcc systemd-devel


And install it from pypi

.. code-block:: bash

    pip install cysystemd


Usage examples
--------------

Writing to journald
+++++++++++++++++++

Logging handler for python logger
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: python

    from cysystemd import journal
    import logging
    import uuid

    logging.basicConfig(level=logging.DEBUG)
    logger = logging.getLogger()
    logger.addHandler(journal.JournaldLogHandler())

    try:
        log.info("Trying to do something")
        raise Exception('foo')
    except:
        logger.exception("Test Exception %s", 1)


Systemd daemon notification
~~~~~~~~~~~~~~~~~~~~~~~~~~~


.. code-block:: python

    from cysystemd.daemon import notify, Notification

    # Send READY=1
    notify(Notification.READY)

    # Send status
    notify(Notification.STATUS, "I'm fine.")

    # Send stopping
    notify(Notification.STOPPING)


Write message into Systemd journal


.. code-block:: python

    from cysystemd import journal


    journal.write("Hello Lennart")

    # Or send structured data
    journal.send(
        message="Hello Lennart",
        priority=journal.Priority.INFO,
        some_field='some value',
    )


Reading journald
++++++++++++++++

Reading all systemd records
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: python

   from cysystemd.reader import JournalReader, JournalOpenMode

   journal_reader = JournalReader()
   journal_reader.open(JournalOpenMode.SYSTEM)
   journal_reader.seek_head()

   for record in journal_reader:
      print(record.data['MESSAGE'])


Read only cron logs
~~~~~~~~~~~~~~~~~~~

.. _read-only-cron-logs:

.. code-block:: python

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


Polling records
~~~~~~~~~~~~~~~

.. code-block:: python

   from cysystemd.reader import JournalReader, JournalOpenMode


   reader = JournalReader()
   reader.open(JournalOpenMode.SYSTEM)
   reader.seek_tail()

   poll_timeout = 255

   while True:
      reader.wait(poll_timeout)

      for record in reader:
         print(record.data['MESSAGE'])


JournalD open modes
~~~~~~~~~~~~~~~~~~~

* CURRENT_USER
* LOCAL_ONLY
* RUNTIME_ONLY
* SYSTEM
* SYSTEM_ONLY


.. code-block:: python

   from cysystemd.reader import JournalReader, JournalOpenMode

   reader = JournalReader()
   reader.open(JournalOpenMode.CURRENT_USER)


JournalD entry
~~~~~~~~~~~~~~

JournalEntry class has some special properties and methods:

* ``data`` - journal entry content (``dict``)
* ``date`` - entry timestamp (``datetime`` instance)
* ``cursor`` - systemd identification bytes for this entry
* ``boot_id()`` - returns bootid
* ``get_realtime_sec()`` - entry epoch (``float``)
* ``get_realtime_usec()`` - entry epoch (``int`` microseconds)
* ``get_monotonic_sec()`` - entry monotonic time (``float``)
* ``get_monotonic_usec()`` - entry monotonic time (``int`` microseconds)
* ``__getitem__(key)`` - shoutcut for ``entry.data[key]``


JournalD reader
~~~~~~~~~~~~~~~

JournalReader class has some special properties and methods:

* ``open(flags=JournalOpenMode.CURRENT_USER)`` - opening journald
  with selected mode
* ``open_directory(path)`` - opening journald from path
* ``open_files(*filename)`` - opening journald from files
* ``data_threshold`` - may be used to get or set the data field size threshold
  for data returned by fething entry data.
* ``closed`` - returns True when journal reader closed
* ``locked`` - returns True when journal reader locked
* ``idle`` - returns True when journal reader opened
* ``seek_head`` - move reader pointer to the first entry
* ``seek_tail`` - move reader pointer to the last entry
* ``seek_monotonic_usec`` - seeks to the entry with the specified monotonic
  timestamp, i.e. CLOCK_MONOTONIC. Since monotonic time restarts on every
  reboot a boot ID needs to be specified as well.
* ``seek_realtime_usec`` - seeks to the entry with the specified realtime
  (wallclock) timestamp, i.e. CLOCK_REALTIME. Note that the realtime clock
  is not necessarily monotonic. If a realtime timestamp is ambiguous, it is
  not defined which position is sought to.
* ``seek_cursor`` - seeks to the entry located at the specified cursor
  (see ``JournalEntry.cursor``).
* ``wait(timeout)`` - It will synchronously wait until the journal gets
  changed. The maximum time this call sleeps may be controlled with the
  timeout_usec parameter.
* ``__iter__`` - returns JournalReader object
* ``__next__`` - calls ``next()`` or raise ``StopIteration``
* ``next(skip=0)`` - returns the next ``JournalEntry``. The ``skip``
  parameter skips some entries.
* ``previous(skip=0)`` - returns the previous ``JournalEntry``.
  The ``skip`` parameter skips some entries.
* ``skip_next(skip)`` - skips next entries.
* ``skip_previous(skip)`` - skips next entries.
* ``add_filter(rule)`` - adding filter rule.
  See `read-only-cron-logs`_ as example.
* ``clear_filter`` - reset all filters
* ``fd`` - returns a special file descriptor
* ``events`` - returns ``EPOLL`` events
* ``timeout`` - returns internal timeout
* ``process_events()`` - After each poll() wake-up process_events() needs
  to be called to process events. This call will also indicate what kind of
  change has been detected.
* ``get_catalog()`` - retrieves a message catalog entry for the current
  journal entry. This will look up an entry in the message catalog by using
  the "MESSAGE_ID=" field of the current journal entry. Before returning
  the entry all journal field names in the catalog entry text enclosed in
  "@" will be replaced by the respective field values of the current entry.
  If a field name referenced in the message catalog entry does not exist,
  in the current journal entry, the "@" will be removed, but the field name
  otherwise left untouched.
* ``get_catalog_for_message_id(message_id: UUID)`` - works similar to
  ``get_catalog()`` but the entry is looked up by the specified
  message ID (no open journal context is necessary for this),
  and no field substitution is performed.


Asyncio support
+++++++++++++++

Initial ``asyncio`` support for reading journal asynchronously.

AsyncJournalReader
~~~~~~~~~~~~~~~~~~

Blocking methods were wrapped by threads.
Method ``wait()`` use epoll on journald file descriptor.

.. code-block:: python

   import asyncio
   import json

   from cysystemd.reader import JournalOpenMode
   from cysystemd.async_reader import AsyncJournalReader


   async def main():
       reader = AsyncJournalReader()
       await reader.open(JournalOpenMode.SYSTEM)
       await reader.seek_tail()

       while await reader.wait():
           async for record in reader:
               print(
                   json.dumps(
                       record.data,
                       indent=1,
                       sort_keys=True
                   )
               )

   if __name__ == '__main__':
       asyncio.run(main())
