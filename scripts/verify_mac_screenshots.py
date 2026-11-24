#!/usr/bin/env python3
"""Check that App Store Mac screenshots exist and use an accepted size."""
import struct
import sys
from pathlib import Path

ACCEPTED = {(1280, 800), (1440, 900), (2560, 1600), (2880, 1800)}
EXPECTED = [
    "01-browse.png",
    "02-notetakers.png",
    "03-braillenote-touch.png",
    "04-search.png",
    "05-compare.png",
    "06-favorites.png",
    "07-about.png",
]


def png_size(path: Path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path.name} is not a PNG")
    width, height = struct.unpack(">II", data[16:24])
    return width, height


def main():
    folder = Path(sys.argv[1] if len(sys.argv) > 1 else "build/mac-screenshots")
    missing = [name for name in EXPECTED if not (folder / name).exists()]
    if missing:
        raise SystemExit("Missing screenshots: " + ", ".join(missing))
    sizes = {}
    checksums = {}
    for name in EXPECTED:
        path = folder / name
        size = png_size(path)
        digest = path.read_bytes()
        print(f"{name}: {size[0]}x{size[1]} ({path.stat().st_size} bytes)")
        if size not in ACCEPTED:
            raise SystemExit(f"{name} is {size[0]}x{size[1]}, not an accepted Mac App Store size")
        sizes[name] = size
        checksums[name] = digest
    unique = {v for v in checksums.values()}
    if len(unique) == 1:
        raise SystemExit("All screenshots are identical; they are not usable App Store shots.")
    print(f"All {len(EXPECTED)} Mac screenshots have an accepted size and are not identical.")


if __name__ == "__main__":
    main()
