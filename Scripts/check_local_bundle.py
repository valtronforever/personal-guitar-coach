#!/usr/bin/env python3
"""Verify a local bundle/ZIP without launching it or requesting microphone access."""
import argparse
import hashlib
import json
from lesson_yaml import loads
import os
from pathlib import Path
import plistlib
import re
import stat
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def run(*command):
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return result.stdout


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compiled_plist(path):
    return json.loads(run("plutil", "-convert", "json", "-o", "-", str(path)))


def verify(app, configuration):
    contents = app / "Contents"
    resources = contents / "Resources"
    info = plistlib.loads((contents / "Info.plist").read_bytes())
    require(info.get("CFBundleIdentifier") == "com.valtronforever.PersonalGuitarCoach", "Unexpected bundle identifier")
    require(info.get("CFBundlePackageType") == "APPL" and info.get("CFBundleExecutable") == "PersonalGuitarCoach", "Invalid app metadata")
    require(info.get("LSMinimumSystemVersion") == "14.0", "Unexpected minimum macOS")
    require(info.get("CFBundleShortVersionString") == "0.1.0" and info.get("CFBundleVersion") == "1", "Unexpected app version")
    require(set(info.get("CFBundleLocalizations", [])) == {"en", "uk"}, "Missing app locales")
    binary = contents / "MacOS" / info["CFBundleExecutable"]
    require(os.access(binary, os.X_OK), "App executable lacks execute permission")
    run("codesign", "--verify", "--deep", "--strict", str(app))
    signature = subprocess.run(["codesign", "-dv", "--verbose=4", str(app)], check=True, capture_output=True, text=True).stderr
    require("Signature=adhoc" in signature and "runtime" in signature, "Expected local ad-hoc hardened runtime signature")
    entitlements = plistlib.loads(run("codesign", "-d", "--entitlements", "-", "--xml", str(app)).encode())
    expected_entitlements = plistlib.loads((ROOT / "App/PersonalGuitarCoach.entitlements").read_bytes())
    require(entitlements == expected_entitlements == {
        "com.apple.security.app-sandbox": True, "com.apple.security.device.audio-input": True
    }, "Unexpected sandbox/audio entitlements")
    require(info.get("CFBundleIconFile") == "AppIcon.icns", "Missing app icon metadata")
    icon = resources / "AppIcon.icns"
    header, length = struct.unpack(">4sI", icon.read_bytes()[:8])
    require(header == b"icns" and length == icon.stat().st_size, "Invalid ICNS container")
    require(digest(icon) == digest(ROOT / "Resources/AppIcon.icns"), "Bundled icon differs from source")
    icon_source = ROOT / "Resources/Assets.xcassets/AppIcon.appiconset"
    icon_manifest = json.loads((icon_source / "Contents.json").read_text())
    require(len(icon_manifest["images"]) == 10, "Expected ten native icon representations")
    for image in icon_manifest["images"]:
        pixels = int(image["size"].split("x")[0]) * int(image["scale"].removesuffix("x"))
        png = (icon_source / image["filename"]).read_bytes()
        require(png[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", png[16:24]) == (pixels, pixels), "Invalid icon PNG dimensions")
    catalogs = [(path.stem, json.loads(path.read_text())["strings"]) for path in (ROOT / "Resources/Localization").glob("*.xcstrings")]
    for language in ["en", "uk"]:
        for table, entries in catalogs:
            folder = resources / (language + ".lproj")
            strings = compiled_plist(folder / (table + ".strings"))
            plural_path = folder / (table + ".stringsdict")
            plurals = compiled_plist(plural_path) if plural_path.exists() else {}
            require(set(strings) | set(plurals) == set(entries), f"Incomplete {language} {table} catalog")
            for key, entry in entries.items():
                unit = entry["localizations"][language].get("stringUnit")
                if unit:
                    require(strings.get(key) == unit["value"], f"Mismatched compiled translation: {language} {key}")
                else:
                    require(key in plurals, f"Missing compiled plurals: {language} {key}")
        reason = compiled_plist(resources / (language + ".lproj") / "InfoPlist.strings").get("NSMicrophoneUsageDescription")
        require(bool(reason), "Missing localized microphone purpose")
    require(bool(info.get("NSMicrophoneUsageDescription")), "Missing fallback microphone purpose")
    source_lessons = ROOT / "Resources/Lessons"
    for license_file in (ROOT / "Resources/ThirdPartyLicenses").glob("*.txt"):
        require(digest(license_file) == digest(resources / "ThirdPartyLicenses" / license_file.name),
                f"Missing or changed dependency license: {license_file.name}")
    bundled_lessons = resources / "Lessons"
    require(not list(bundled_lessons.rglob("*.json")), "Stale JSON lesson resources in bundle")
    files = sorted(path.relative_to(source_lessons) for path in source_lessons.rglob("*.yml"))
    require(files == sorted(path.relative_to(bundled_lessons) for path in bundled_lessons.rglob("*.yml")), "Lesson resource set differs")
    for path in files:
        require(digest(source_lessons / path) == digest(bundled_lessons / path), f"Changed bundled lesson: {path}")
    lesson_count = len(loads((bundled_lessons / "catalog.yml").read_text())["lessons"])
    require(lesson_count >= 6, "Starter course is incomplete")
    linked = run("otool", "-L", str(binary)).splitlines()[1:]
    dependencies = [line.strip().split(" (", 1)[0] for line in linked if line.strip()]
    for dependency in dependencies:
        require(dependency.startswith(("/System/Library/", "/usr/lib/")), f"Non-system dynamic dependency: {dependency}")
    build = run("xcrun", "vtool", "-show-build", str(binary))
    platforms = re.findall(r"platform\s+(\w+)", build)
    minimums = re.findall(r"minos\s+([\d.]+)", build)
    require(platforms and all(value == "MACOS" for value in platforms), "Unexpected Mach-O platform")
    require(minimums and all(value == "14.0" for value in minimums), "Binary deployment target differs from Info.plist")
    if configuration == "release":
        symbols = run("nm", str(binary))
        require(not any(name in symbols for name in ["AssessmentFixtureView", "VisualFixtureView", "TunerFixtureView"]), "Debug fixture code in Release")
    architectures = run("lipo", "-archs", str(binary)).strip().split()
    return {
        "configuration": configuration, "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"],
        "architectures": architectures, "minimumMacOS": minimums, "binarySHA256": digest(binary),
        "signature": "adhoc", "hardenedRuntime": True, "entitlements": entitlements,
        "iconRepresentations": len(icon_manifest["images"]), "lessonCount": lesson_count, "lessonYAMLFiles": len(files),
        "locales": ["en", "uk"], "systemDynamicDependencies": len(dependencies),
        "offlineResourcesVerified": True, "appLaunchVerified": False, "hardwareVerified": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--configuration", choices=["debug", "release"], default="release")
    parser.add_argument("--archive", type=Path, help="Also extract and verify this local ZIP in a temporary directory.")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = verify(args.app.resolve(), args.configuration)
    if args.archive:
        with zipfile.ZipFile(args.archive) as zipped:
            for item in zipped.infolist():
                path = Path(item.filename)
                require(not path.is_absolute() and ".." not in path.parts, "Unsafe archive path")
                require(not stat.S_ISLNK(item.external_attr >> 16), "Unexpected archive symlink")
        with tempfile.TemporaryDirectory(prefix="coach-bundle-check-") as temporary:
            run("ditto", "-x", "-k", str(args.archive.resolve()), temporary)
            extracted = verify(Path(temporary) / args.app.name, args.configuration)
            require(extracted == report, "Archive payload differs from verified bundle")
        report["archiveSHA256"] = digest(args.archive)
        report["archiveVerified"] = True
    text = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(text)
    print(text, end="")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError, plistlib.InvalidFileException, zipfile.BadZipFile) as error:
        raise SystemExit(f"Bundle validation failed: {error}")
