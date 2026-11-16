#!/usr/bin/env python3
"""Print the UDID of a 6.9-inch-class iPhone simulator (Pro Max).

Prefers iPhone 16 Pro Max (1320x2868), then other Pro Max models that
produce accepted 6.9-inch App Store sizes (1320x2868 or 1290x2796).
Reads `xcrun simctl list devices available -j` on stdin, or creates a
device if --create is passed (then lists device types and runtimes itself).
"""
import json, re, subprocess, sys

# Higher score is better. Names that historically map to accepted 6.9" sizes.
PREFERRED = [
    (100, re.compile(r"^iPhone 16 Pro Max$")),
    (95, re.compile(r"^iPhone 17 Pro Max$")),
    (90, re.compile(r"^iPhone \d+ Pro Max$")),  # 15 Pro Max is 1290x2796, also accepted
]


def score_name(name: str) -> int:
    for score, pat in PREFERRED:
        if pat.search(name):
            return score
    return 0


def best_runtime():
    data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "available", "-j"]))
    best = None
    for runtime in data.get("runtimes", []):
        if runtime.get("isAvailable") is False:
            continue
        identifier = runtime.get("identifier", "")
        name = runtime.get("name", "")
        match = re.search(r"iOS-(\d+)-(\d+)", identifier) or re.search(r"iOS (\d+)\.(\d+)", name)
        if not match or int(match.group(1)) < 17:
            continue
        version = (int(match.group(1)), int(match.group(2)))
        if best is None or version > best[0]:
            best = (version, identifier)
    if best is None:
        sys.exit("No iOS 17+ simulator runtime installed")
    return best[1]


def best_device_type():
    data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devicetypes", "-j"]))
    best = None
    for item in data.get("devicetypes", []):
        name = item.get("name", "")
        s = score_name(name)
        if s == 0:
            continue
        key = (s, name)
        if best is None or key > best[0]:
            best = (key, item["identifier"], name)
    if best is None:
        sys.exit("No iPhone Pro Max simulator device type installed")
    return best[1], best[2]


def pick_existing():
    data = json.load(sys.stdin)
    best = None
    for runtime, items in data.get("devices", {}).items():
        m = re.search(r"iOS-(\d+)-(\d+)", runtime)
        if not m or int(m.group(1)) < 17:
            continue
        version = (int(m.group(1)), int(m.group(2)))
        for d in items:
            if d.get("isAvailable") is False:
                continue
            name = d.get("name", "")
            s = score_name(name)
            if s == 0:
                continue
            key = (s, version, name)
            if best is None or key > best[0]:
                best = (key, d["udid"], name, runtime)
    return best


def main():
    if "--create" in sys.argv:
        dtype, dname = best_device_type()
        runtime = best_runtime()
        print(f"Creating {dname} on {runtime}", file=sys.stderr)
        udid = subprocess.check_output(
            ["xcrun", "simctl", "create", "ATSpotlight App Store iPhone", dtype, runtime],
            text=True,
        ).strip()
        print(udid)
        print(f"name={dname}", file=sys.stderr)
        return

    best = pick_existing()
    if best is None:
        sys.exit("No iPhone Pro Max simulator found")
    print(best[1])
    print(f"name={best[2]} runtime={best[3]}", file=sys.stderr)


if __name__ == "__main__":
    main()
