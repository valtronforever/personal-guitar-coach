#!/usr/bin/env python3
"""Check measured DSP gates and optionally write a compact, reviewable benchmark artifact."""
import argparse
import json
import math
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("report", type=Path)
parser.add_argument("--compact", type=Path)
args = parser.parse_args()
report = json.loads(args.report.read_text())
assert report["schemaVersion"] == 1 and report["algorithmVersion"] == "mono-mpm-flux-3"
cases = report["cases"]
assert len(cases) >= (3360 if report["mode"] == "full" else 360)
assert len({(c["source"], c["method"], c["sampleRate"], c["id"]) for c in cases}) == len(cases)
summaries = {s["source"]: s for s in report["summaries"] if s["method"] == "mpm"}
synthetic = summaries["synthetic"]
assert synthetic["pitchErrorCents"]["median"] <= 5 and synthetic["pitchErrorCents"]["p95"] <= 10
assert synthetic["fractionWithin15Cents"] >= .99 and synthetic["extraOnsets"] == 0
assert synthetic["onsetRecall"] == 1
for source in ["synthetic", "durationMatrix", "recorded"]:
    summary = summaries[source]
    assert summary["onsetErrorMs"]["median"] <= 15.001 and summary["onsetErrorMs"]["p95"] <= 30.001, source
    assert summary["noteResolutionMs"]["p95"] <= 300, source
    assert summary["realTimeFactor"] < 1, source
recorded = summaries["recorded"]
assert recorded["fractionWithin15Cents"] >= .95 and recorded["onsetRecall"] >= .95
# Additional unpitched transients in source recordings count conservatively as false positives.
assert recorded["extraOnsets"] <= 4
for case in cases:
    if case["method"] != "mpm": continue
    if case["source"] == "negative":
        assert case["reliableFrames"] == 0, case["id"]
        assert all(event["quality"] != "reliable" for event in case["events"]), case["id"]
    if case["source"] == "durationMatrix" and "duration0.125" not in case["id"]:
        assert case["missedOnsets"] == 0 and case["extraOnsets"] == 0, (case["id"], case["sampleRate"])
        assert case["reliableFrames"] >= case["stableFrames"] * .95, case["id"]
        assert all(event["quality"] == "reliable" for event in case["events"]), case["id"]

def metrics(values):
    ordered = sorted(values)
    if not ordered: return {"count": 0}
    return {"count": len(ordered), "median": ordered[math.ceil(len(ordered)*.5)-1],
            "p95": ordered[math.ceil(len(ordered)*.95)-1], "maximum": ordered[-1]}

if args.compact:
    compact = dict(report)
    compact["artifactFormat"] = "Per-case aggregate errors; rerun BenchmarkAudio for individual frame errors and onset events."
    compact["cases"] = []
    for case in cases:
        value = dict(case)
        for field in ["pitchErrorsCents", "onsetErrorsMs", "noteResolutionMs"]: value[field] = metrics(value[field])
        value.pop("events")
        compact["cases"].append(value)
    args.compact.parent.mkdir(parents=True, exist_ok=True)
    case_rows = compact.pop("cases")
    metadata = json.dumps(compact, indent=2, ensure_ascii=False)
    rows = ",\n".join("    " + json.dumps(value, separators=(",", ":"), ensure_ascii=False) for value in case_rows)
    args.compact.write_text(metadata[:-2] + ',\n  "cases": [\n' + rows + "\n  ]\n}\n")
print(f"DSP benchmark gates passed: {len(cases)} cases ({report['mode']}), including recorded corpus and supported duration matrix.")
