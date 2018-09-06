SystemD wrapper on Cython
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

Systemd daemon notification


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



Or add logging handler to python logger

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

