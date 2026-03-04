from setuptools import Extension, setup

import cysystemd as module


try:
    from Cython.Build import cythonize

    extensions = cythonize(
        [
            Extension(
                "cysystemd._daemon",
                ["cysystemd/_daemon.pyx"],
                libraries=["systemd"],
            ),
            Extension(
                "cysystemd._journal",
                ["cysystemd/_journal.pyx"],
                libraries=["systemd"],
                extra_compile_args=["-DSYSLOG_NAMES=1",],
            ),
            Extension(
                "cysystemd.reader",
                ["cysystemd/reader.pyx"],
                libraries=["systemd"],
                extra_compile_args=["-DSYSLOG_NAMES=1",],
            ),
        ],
        compiler_directives={"language_level": "3"},
        force=True,
        emit_linenums=True,
    )

except ImportError:
    extensions = [
        Extension(
            "cysystemd._daemon",
            ["cysystemd/_daemon.c"],
            libraries=["systemd"],
        ),
        Extension(
            "cysystemd._journal",
            ["cysystemd/_journal.c"],
            libraries=["systemd"],
            extra_compile_args=["-DSYSLOG_NAMES=1",],
        ),
        Extension(
            "cysystemd.reader",
            ["cysystemd/reader.c"],
            libraries=["systemd"],
            extra_compile_args=["-DSYSLOG_NAMES=1",],
        ),
    ]


setup(
    name=module.__name__,
    ext_modules=extensions,
    version=module.__version__,
    packages=["cysystemd",],
    package_data={"cysystemd": ["py.typed"]},
    license=module.license,
    description=module.package_info,
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    platforms=["POSIX"],
    url="https://github.com/mosquito/cysystemd",
    project_urls={
        "Source": "https://github.com/mosquito/cysystemd",
        "Tracker": "https://github.com/mosquito/cysystemd/issues",
        "Releases": "https://github.com/mosquito/cysystemd/releases",
    },
    author=module.__author__,
    author_email=module.author_email,
    keywords=[
        "systemd", "cython", "daemon", "sd_notify", "sd_watchdog",
        "journald", "journal", "logging", "linux", "asyncio",
        "libsystemd", "syslog", "service", "notify",
    ],
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Environment :: No Input/Output (Daemon)",
        "Intended Audience :: Developers",
        "Intended Audience :: System Administrators",
        "License :: OSI Approved :: Apache Software License",
        "Natural Language :: English",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Cython",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: 3.13",
        "Programming Language :: Python :: 3.14",
        "Programming Language :: Python :: Implementation :: CPython",
        "Topic :: Software Development :: Libraries",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: System",
        "Topic :: System :: Logging",
        "Topic :: System :: Operating System",
        "Topic :: System :: Systems Administration",
        "Typing :: Typed",
    ],
    python_requires=">=3.8, <4",
)
