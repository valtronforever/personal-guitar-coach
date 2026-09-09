#!/usr/bin/env python3
"""Regenerate the small public guitar corpus; requires NumPy/SciPy, not used by CI.

Downloads are explicit with --download; otherwise the three original AIFF files
must be supplied in --source-dir. No private microphone recording is performed.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
from urllib.parse import quote
from urllib.request import urlopen
import numpy as np
import scipy
from scipy.signal import butter, sosfilt, resample_poly
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    ("Guitar.mf.sulE.E2B2.mono.aif", 40, [0.09, 10.85, 22.78, 34.04, 45.75, 56.21, 63.94, 73.26]),
    ("Guitar.mf.sulB.B3.mono.aif", 59, [0.0]),
    ("Guitar.mf.sul_E.E4B4.mono.aif", 64, [0.03, 7.34, 15.54, 22.88, 30.04, 38.06, 45.4, 52.41]),
]

def read_aiff(path):
    data = path.read_bytes()
    if data[:4] != b"FORM" or data[8:12] != b"AIFF":
        raise ValueError("Only uncompressed AIFF source files are supported")
    chunks = {}; offset = 12
    while offset + 8 <= len(data):
        name, length = struct.unpack_from(">4sI", data, offset)
        chunks[name] = data[offset + 8:offset + 8 + length]
        offset += 8 + length + length % 2
    channels, count, bits = struct.unpack_from(">hIh", chunks[b"COMM"])
    exponent, mantissa = struct.unpack_from(">HQ", chunks[b"COMM"], 8)
    rate = round(math.ldexp(mantissa, exponent - 16383 - 63))
    if channels != 1 or bits != 24 or rate != 96000:
        raise ValueError("Unexpected source format")
    skip, _ = struct.unpack_from(">II", chunks[b"SSND"])
    b = np.frombuffer(chunks[b"SSND"][8 + skip:], dtype=np.uint8).reshape(-1, 3).astype(np.int32)
    x = (b[:, 0] << 16) | (b[:, 1] << 8) | b[:, 2]
    if len(x) != count: raise ValueError("Truncated source")
    return rate, np.where(x >= 2**23, x - 2**24, x).astype(np.float64) / 2**23

def reference_frequency(x, rate, nominal):
    """Independent long-window harmonic spectral reference; no production detector calls."""
    spectrum = np.abs(np.fft.rfft(x * np.hanning(len(x)), n=262144))
    frequencies = np.fft.rfftfreq(262144, 1 / rate)
    candidates = []
    for harmonic in range(1, 7):
        indices = np.flatnonzero((frequencies > nominal * harmonic * 2**(-80/1200)) &
                                 (frequencies < nominal * harmonic * 2**(80/1200)))
        center = indices[np.argmax(spectrum[indices])]
        left, middle, right = np.log(np.maximum(spectrum[center-1:center+2], 1e-12))
        shift = 0.5 * (left - right) / (left - 2 * middle + right)
        candidates.append(((center + shift) * rate / 262144 / harmonic, float(spectrum[center])))
    loudest = sorted(candidates, key=lambda pair: pair[1], reverse=True)[:3]
    return float(np.median([pair[0] for pair in loudest]))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--download", action="store_true")
    args = parser.parse_args()
    args.source_dir.mkdir(parents=True, exist_ok=True)
    output = ROOT / "Tests/Fixtures/Audio"
    output.mkdir(parents=True, exist_ok=True)
    manifest = {"schemaVersion": 1, "source": "University of Iowa Musical Instrument Samples, guitar, 2011-12-11",
                "licenseURL": "https://theremin.music.uiowa.edu/MIS.html", "sources": [], "clips": [],
                "generator": {"numpy": np.__version__, "scipy": scipy.__version__}}
    for filename, first_midi, approximate_onsets in SOURCES:
        url = "https://theremin.music.uiowa.edu/" + quote("sound files/MIS/Piano_Other/guitar/" + filename)
        path = args.source_dir / filename
        if args.download and not path.exists():
            with urlopen(url, timeout=60) as response: path.write_bytes(response.read())
        rate, original = read_aiff(path)
        manifest["sources"].append({"file": filename, "url": url, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                    "sampleRate": rate, "channels": 1, "bits": 24})
        # Only the annotation envelope is filtered. Stored clips preserve the original waveform.
        high_pass = sosfilt(butter(2, 40, btype="highpass", fs=rate, output="sos"), original)
        for number, approximate in enumerate(approximate_onsets):
            midi = first_midi + number
            search_start = max(0, round((approximate - 0.05) * rate))
            search_end = min(len(original), round((approximate + 0.2) * rate))
            hop = rate // 1000
            segment = high_pass[search_start:search_end]
            envelope = np.sqrt(np.mean(segment[:len(segment)//hop*hop].reshape(-1, hop)**2, axis=1))
            threshold = max(0.0008, float(np.max(envelope)) * 0.035)
            active = np.flatnonzero(envelope > threshold)
            if not len(active): raise ValueError(f"No attack in annotation window: {filename} {approximate}")
            onset_frame = search_start + int(active[0]) * hop
            start = max(0, onset_frame - round(0.1 * rate))
            padding = round(0.1 * rate) - (onset_frame - start)
            clip = np.concatenate([np.zeros(padding), original[start:onset_frame + round(1.1 * rate)]])
            nominal = 440 * 2**((midi - 69)/12)
            reference = reference_frequency(original[onset_frame + round(.3*rate):onset_frame + round(1.1*rate)], rate, nominal)
            for destination_rate in [44100, 48000]:
                divisor = math.gcd(rate, destination_rate)
                converted = resample_poly(clip, destination_rate // divisor, rate // divisor).astype(np.float32)
                name = f"iowa-midi{midi}-{destination_rate}.wav"
                target = output / name
                wavfile.write(target, destination_rate, converted)
                manifest["clips"].append({"file": name, "sourceFile": filename, "sourceStartFrame": start,
                    "sourceOnsetFrame": onset_frame, "sourceEndFrame": onset_frame + round(1.1*rate), "paddingFrames": padding,
                    "sampleRate": destination_rate, "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                    "nominalMIDI": midi, "referenceHz": reference, "stableStart": .3, "stableEnd": 1.0,
                    "onsetSeconds": None if onset_frame < round(.02 * rate) else .1, "onsetUncertaintyMs": 10,
                    "annotation": "Nominal chromatic label from source filename; long-window harmonic spectral reference; independent 1 ms high-pass RMS onset threshold (not human ground truth)."})
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {len(manifest['clips'])} clips to {output}")

if __name__ == "__main__": main()
