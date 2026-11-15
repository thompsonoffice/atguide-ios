#!/usr/bin/env python3
"""Print the path of the newest installed Xcode.

macOS `sort` has no -V, and /Applications contains both real apps and
versioned symlinks (Xcode_26.3.app and Xcode_26.3.0.app). Resolve symlinks
so each install is counted once, then pick the highest version.
"""
import glob
import os
import re
import sys


def version_key(path):
    name = os.path.basename(path.rstrip("/"))
    match = re.search(r"Xcode_(\d+(?:\.\d+)*)", name)
    if not match:
        return (0,)
    return tuple(int(part) for part in match.group(1).split("."))


def newest_xcode(roots=("/Applications",)):
    found = []
    for root in roots:
        found.extend(glob.glob(os.path.join(root, "Xcode_*.app")))
        found.extend(glob.glob(os.path.join(root, "Xcode.app")))
    unique = {}
    for path in found:
        unique.setdefault(os.path.realpath(path), path)
    if not unique:
        return None
    return max(unique, key=version_key)


def main():
    path = newest_xcode()
    if path is None:
        sys.exit("No Xcode.app found under /Applications")
    print(path)


if __name__ == "__main__":
    main()
