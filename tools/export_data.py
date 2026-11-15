#!/usr/bin/env python3
"""Export ATGuide/Resources/atguide-data.json from the ATGuide 2.0 web guide's index.html.

Usage: python3 tools/export_data.py path/to/ATGuide/index.html [YYYY-MM-DD]
Source used for this app: "ATGuide 2.0.zip" (release candidate, research date November 13, 2026),
file ATGuide/index.html. Every device, company, OS history and trivia record is carried over.
"""
import json, re, sys, pathlib

src = sys.argv[1] if len(sys.argv) > 1 else "index.html"
generated = sys.argv[2] if len(sys.argv) > 2 else "2026-11-13"
html = open(src, encoding="utf-8").read()
D = json.loads(re.search(r"<script>window\.ATG=(.*?);</script>", html, re.S).group(1))

# Core spec keys (shown in the Specs section, same rules as the website).
SK = {"cpu": "processor", "ram": "memory", "sto": "storage", "os": "operatingSystem", "tts": "speech",
      "bat": "battery", "disp": "display", "price": "price", "syn": "synthesis", "plat": "platforms",
      "def": "defaultOn", "syns": "synthesizersAvailable", "used": "usedPrice"}
# Other spec keys, shown under "More specs" with these labels.
EXTRA = {"dim": "Dimensions", "wt": "Weight", "io": "Connections", "out": "Output", "conn": "Connectivity",
         "cells": "Braille cells", "cap": "Capacity", "net": "Network", "kbd": "Keyboard", "cam": "Camera",
         "pwr": "Power", "power": "Power", "warranty": "Warranty", "files": "File formats",
         "mag": "Magnification", "models": "Models", "time": "Run time", "lang": "Languages"}
ORDER = ["Notetakers", "VoiceNotes", "BrailleSense", "VoiceSense", "PDAs", "Braille Displays", "Book Readers",
         "Speech Synthesizers", "TTS Voices", "Screen Readers", "Accessible Linux", "Magnifiers",
         "Vision Wearables", "Embossers", "Echo Speakers", "Echo Displays", "Echo Mobile", "Echo Accessories",
         "Smart Home", "iRobot Vacuums", "iRobot Mops", "Miscellaneous", "Other"]
present = {d["cat"] for d in D["DEV"]}
cats = [c for c in ORDER if c in present] + sorted(present - set(ORDER))

def drop(d):
    return {k: v for k, v in d.items() if v not in (None, [], {}, "")}

def specs(s):
    s = s or {}
    core = {SK[k]: v for k, v in s.items() if k in SK and v}
    extra = [{"label": EXTRA.get(k, k), "value": v} for k, v in s.items() if k not in SK and v]
    return core, extra

devices = []
for d in D["DEV"]:
    core, extra = specs(d.get("s"))
    devices.append(drop(dict(
        id=d["id"], name=d["n"], company=d["co"], category=d["cat"], year=d.get("yr", 0), released=d.get("y"),
        overview=d.get("o"), physical=d.get("ph"), details=list(d.get("desc") or []), features=d.get("f", []),
        history=d.get("h"), ports=d.get("io"), specs=core, moreSpecs=extra, requirements=d.get("req", []),
        predecessors=d.get("pre", []), successors=d.get("suc", []), voices=d.get("vo", []), sources=d.get("src", []))))

out = dict(
    version=2,
    edition="ATGuide 2.0",
    generated=generated,
    categories=cats,
    companies=[drop(dict(id=c["id"], name=c["n"], founded=c.get("f"), history=c.get("h"), sources=c.get("src", [])))
               for c in D["CO"]],
    devices=devices,
    osHistories=[drop(dict(id=o["id"], name=o["n"], company=o["co"], overview=o.get("h"),
                           versions=[dict(name=v[0], released=v[1], notes=v[2]) for v in o["v"]],
                           devices=o.get("d", []), requirements=o.get("req", []), sources=o.get("src", [])))
                 for o in D["OSL"]],
    trivia=[drop(dict(text=t["t"], device=t.get("d"), level=t["lv"])) for t in D["TRIV"]],
)
dest = pathlib.Path(__file__).resolve().parent.parent / "ATGuide" / "Resources" / "atguide-data.json"
dest.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print("wrote", dest, len(out["companies"]), "companies,", len(out["devices"]), "devices,",
      len(out["osHistories"]), "OS histories,", len(out["trivia"]), "trivia,", len(cats), "categories")
