#!/usr/bin/env python3
"""Validate catalog completeness and literal UI keys without requiring Xcode extraction."""
import json
from pathlib import Path
import re
from collections import Counter

root = Path(__file__).resolve().parents[1]
errors = []

def units(value):
    if isinstance(value, dict):
        if "stringUnit" in value:
            yield value["stringUnit"]
        for key, child in value.items():
            if key != "stringUnit":
                yield from units(child)

def placeholders(text):
    return Counter(re.sub(r"%\d+\$", "%", item) for item in re.findall(r"%(?:\d+\$)?(?:lld|ld|d|u|@|f)", text))

for catalog in (root / "Resources/Localization").glob("*.xcstrings"):
    data = json.loads(catalog.read_text())
    for key, entry in data["strings"].items():
        baseline = None
        for language in ("en", "uk"):
            translations = list(units(entry.get("localizations", {}).get(language, {})))
            if not translations:
                errors.append(f"{catalog.name}: {key}: missing {language}")
            for unit in translations:
                if unit.get("state") != "translated" or not unit.get("value"):
                    errors.append(f"{catalog.name}: {key}: incomplete {language}")
                tokens = placeholders(unit.get("value", ""))
                if baseline is None:
                    baseline = tokens
                elif tokens != baseline:
                    errors.append(f"{catalog.name}: {key}: mismatched format placeholders")

keys = json.loads((root / "Resources/Localization/Localizable.xcstrings").read_text())["strings"]
pattern = re.compile(r'(?:Text|Label|Button|Picker|Section|accessibilityLabel|accessibilityHint|localized)\(\s*"([a-z][a-zA-Z0-9.]+)"')
for source in (root / "App").rglob("*.swift"):
    text = source.read_text()
    for number, line in enumerate(text.splitlines(), 1):
        if re.search(r'LocalizedStringKey\("[^"\n]*\\\(', line):
            errors.append(f"{source.name}:{number}: build computed localization keys as String variables; use Text interpolation for translated arguments")
    for key in pattern.findall(text):
        if "." in key and key not in keys:
            errors.append(f"{source.name}: missing key {key}")
if errors:
    raise SystemExit("\n".join(errors))
print(f"Localization validation passed: {len(keys)} UI keys, en/uk translations and format placeholders.")
