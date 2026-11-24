#!/usr/bin/env python3
"""Pad a captured Mac window PNG to an accepted App Store size (1280x800).

The GitHub-hosted macOS runner often yields a real window slightly shorter
than 800 points (Access Mastery captured 1280x684). Place the window at the
top and fill the remaining bottom with the last row's color, the same way
those shots were finished.
"""
import sys
from pathlib import Path

from PIL import Image

ACCEPTED = {(1280, 800), (1440, 900), (2560, 1600), (2880, 1800)}
TARGET = (1280, 800)


def pad(path: Path) -> None:
    image = Image.open(path)
    if image.size in ACCEPTED:
        print(f"{path.name}: already {image.size[0]}x{image.size[1]}")
        return
    rgb = image.convert("RGB")
    width, height = rgb.size
    target_w, target_h = TARGET
    if width > target_w or height > target_h:
        rgb.thumbnail(TARGET, Image.Resampling.LANCZOS)
        width, height = rgb.size
    fill = rgb.getpixel((width // 2, height - 1)) if height and width else (255, 255, 255)
    canvas = Image.new("RGB", TARGET, fill)
    x = max(0, (target_w - width) // 2)
    y = 0 if height <= target_h else 0
    canvas.paste(rgb, (x, y))
    canvas.save(path, "PNG")
    print(f"{path.name}: padded {width}x{height} -> {target_w}x{target_h}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("usage: pad_mac_screenshot.py <png>")
    pad(Path(sys.argv[1]))
