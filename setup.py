#!/usr/bin/env python
# encoding: utf-8
import systemd as module
from setuptools import setup, Extension


try:
    from Cython.Build import cythonize

    extensions = cythonize([
        Extension(
            "systemd._daemon",
            ["systemd/_daemon.pyx"],
            libraries=['systemd'],
        ),
        Extension(
            "systemd._journal",
            ["systemd/_journal.pyx"],
            libraries=['systemd',],
            extra_compile_args=[
                '-DSYSLOG_NAMES=1',
            ]
        ),
    ], force=True, emit_linenums=True)

except ImportError:
    extensions = [
        Extension(
            "systemd._daemon",
            ["systemd/_daemon.c"],
            libraries=['systemd'],
        ),
        Extension(
            "systemd._journal",
            ["systemd/_journal.c"],
            libraries=['systemd',],
            extra_compile_args=[
                '-DSYSLOG_NAMES=1',
            ]
        ),
    ]


setup(
    name=module.__name__,
    ext_modules=extensions,
    version=module.__version__,
    packages=[
        'systemd',
    ],
    license=module.license,
    description=module.package_info,
    long_description=open("README.rst").read(),
    platforms=["POSIX"],
    url='http://github.com/mosquito/python-systemd',
    author=module.__author__,
    author_email=module.author_email,
    provides=["systemd"],
    build_requires=['cython'],
    keywords="systemd, python, daemon, sd_notify, cython",
    classifiers=[
        'Development Status :: 4 - Beta',
        'Environment :: Console',
        'Intended Audience :: Developers',
        'Intended Audience :: Education',
        'Intended Audience :: End Users/Desktop',
        'License :: OSI Approved :: Apache Software License',
        'Natural Language :: English',
        'Natural Language :: Russian',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: Cython',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3 :: Only',
        'Programming Language :: Python :: 3.4',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: Implementation :: CPython',
        'Topic :: Software Development :: Libraries',
        'Topic :: System',
        'Topic :: System :: Operating System',
    ],
)