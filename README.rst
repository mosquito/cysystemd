SystemD
=======

Python systemd wrapper using Cython

Systemd daemon notification


.. code-block:: python

    from systemd.daemon import notify, Notification

    # Send READY=1
    notify(Notification.READY)

    # Send status
    notify(Notification.STATUS, "I'm fine.")

    # Send stopping
    notify(Notification.STOPPING)


Write message into Systemd journal


.. code-block:: python

    from systemd import journal

    journal.write("Hello Lennart")
