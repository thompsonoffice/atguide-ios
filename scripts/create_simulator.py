#!/usr/bin/env python3
"""Create one iPhone simulator on the newest installed iOS 17+ runtime.

Used only when scripts/pick_simulator.py finds nothing, which happens on a
runner image that has the runtime but no pre-created iPhone device.
"""
import json
import re
import subprocess
import sys


def simctl_json(*args):
    raw = subprocess.check_output(["xcrun", "simctl", *args, "-j"])
    return json.loads(raw)


def main():
    best_runtime = None
    for runtime in simctl_json("list", "runtimes", "available").get("runtimes", []):
        if runtime.get("isAvailable") is False:
            continue
        identifier = runtime.get("identifier", "")
        name = runtime.get("name", "")
        match = re.search(r"iOS-(\d+)-(\d+)", identifier) or re.search(r"iOS (\d+)\.(\d+)", name)
        if not match or int(match.group(1)) < 17:
            continue
        version = (int(match.group(1)), int(match.group(2)))
        if best_runtime is None or version > best_runtime[0]:
            best_runtime = (version, identifier)
    if best_runtime is None:
        sys.exit("No iOS 17+ simulator runtime installed")

    device_type = None
    preferred = []
    for item in simctl_json("list", "devicetypes").get("devicetypes", []):
        name = item.get("name", "")
        if not name.startswith("iPhone"):
            continue
        rank = 3 if re.fullmatch(r"iPhone \d+ Pro Max", name) else 2 if re.fullmatch(r"iPhone \d+ Pro", name) else 1 if name.startswith("iPhone") else 0
        preferred.append((rank, name, item["identifier"]))
    if not preferred:
        sys.exit("No iPhone simulator device type installed")
    preferred.sort()
    device_type = preferred[-1][2]
    print(f"Creating {preferred[-1][1]} on {best_runtime[1]}", file=sys.stderr)
    subprocess.check_call(["xcrun", "simctl", "create", "ATGuide CI iPhone", device_type, best_runtime[1]])


if __name__ == "__main__":
    main()
