#!/usr/bin/env python3
"""Inject version from git tag into package sources before building."""
import re
import sys
from pathlib import Path


def bump(version: str) -> None:
    version = version.lstrip("v")
    major, minor, patch = (int(x) for x in version.split("."))

    init_path = Path("cysystemd/__init__.py")
    init_path.write_text(
        re.sub(
            r"^version_info = \(.*\)",
            f"version_info = ({major}, {minor}, {patch})",
            init_path.read_text(),
            flags=re.MULTILINE,
        )
    )
    print(f"cysystemd/__init__.py: version_info = ({major}, {minor}, {patch})")

    changelog_path = Path("debian/changelog")
    changelog_path.write_text(
        re.sub(
            r"^cysystemd \([^)]+\)",
            f"cysystemd ({version}-1)",
            changelog_path.read_text(),
            count=1,
            flags=re.MULTILINE,
        )
    )
    print(f"debian/changelog: cysystemd ({version}-1)")


if __name__ == "__main__":
    bump(sys.argv[1])
