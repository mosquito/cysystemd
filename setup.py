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
    url="http://github.com/mosquito/cysystemd",
    author=module.__author__,
    author_email=module.author_email,
    provides=["systemd"],
    build_requires=["cython"],
    keywords=["systemd", "python", "daemon", "sd_notify", "cython"],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Environment :: Console",
        "Intended Audience :: Developers",
        "Intended Audience :: Education",
        "Intended Audience :: End Users/Desktop",
        "License :: OSI Approved :: Apache Software License",
        "Natural Language :: English",
        "Natural Language :: Russian",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Cython",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: Implementation :: CPython",
        "Topic :: Software Development :: Libraries",
        "Topic :: System",
        "Topic :: System :: Operating System",
    ],
    python_requires=">3.6, <4",
)
