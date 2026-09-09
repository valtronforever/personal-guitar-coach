#!/usr/bin/env python3
"""Verify committed audio provenance and PCM assets without downloading or recording."""
import hashlib
import json
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[1] / "Tests/Fixtures/Audio"
manifest = json.loads((root / "manifest.json").read_text())
assert manifest["schemaVersion"] == 1
assert manifest["licenseURL"] == "https://theremin.music.uiowa.edu/MIS.html"
sources = {source["file"]: source for source in manifest["sources"]}
assert len(sources) == 3
names = set()
for clip in manifest["clips"]:
    name = clip["file"]
    assert Path(name).name == name and name.endswith(".wav") and name not in names
    names.add(name)
    assert clip["sourceFile"] in sources
    assert len(sources[clip["sourceFile"]]["sha256"]) == 64
    assert sources[clip["sourceFile"]]["url"].startswith("https://theremin.music.uiowa.edu/")
    data = (root / name).read_bytes()
    assert hashlib.sha256(data).hexdigest() == clip["sha256"], name
    assert data[:4] == b"RIFF" and data[8:12] == b"WAVE"
    offset = 12; chunks = {}
    while offset + 8 <= len(data):
        kind, length = struct.unpack_from("<4sI", data, offset)
        chunks[kind] = data[offset + 8:offset + 8 + length]
        assert len(chunks[kind]) == length
        offset += 8 + length + length % 2
    format_id, channels, rate, _, block, bits = struct.unpack_from("<HHIIHH", chunks[b"fmt "])
    assert (format_id, channels, block, bits) == (3, 1, 4, 32), name
    assert rate == clip["sampleRate"] and rate in [44100, 48000]
    assert abs(len(chunks[b"data"]) / block / rate - 1.2) < 1 / rate
    assert 35 < clip["referenceHz"] < 1500
    assert 0 <= clip["stableStart"] < clip["stableEnd"] <= 1.2
assert len(names) == 34 and names == {path.name for path in root.glob("*.wav")}
print("Audio fixture validation passed: 34 public clips, hashes, provenance and 44.1/48 kHz mono PCM.")
