#!/usr/bin/env python3
"""Build, verify and install a local ad-hoc app bundle; optionally make a local ZIP."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--configuration", choices=["debug", "release"], default="debug")
parser.add_argument("--archive", action="store_true", help="Also create a local ZIP beside the app (no upload).")
args = parser.parse_args()
environment = os.environ.copy()
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")


def run(*command, capture=False):
    result = subprocess.run(command, cwd=ROOT, env=environment, check=True,
                            text=True, stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else None


run("swift", "build", "--configuration", args.configuration)
binary_directory = Path(run("swift", "build", "--configuration", args.configuration, "--show-bin-path", capture=True))
app = ROOT / "build" / args.configuration / "PersonalGuitarCoach.app"
app.parent.mkdir(parents=True, exist_ok=True)
# Finish compilation/resource assembly/signature verification before replacing a usable bundle.
with tempfile.TemporaryDirectory(prefix=".bundle-", dir=app.parent) as temporary:
    staging = Path(temporary) / app.name
    contents = staging / "Contents"
    resources = contents / "Resources"
    (contents / "MacOS").mkdir(parents=True)
    resources.mkdir()
    shutil.copy2(binary_directory / "PersonalGuitarCoach", contents / "MacOS/PersonalGuitarCoach")
    info = {
        "CFBundleExecutable": "PersonalGuitarCoach",
        "CFBundleIdentifier": "com.valtronforever.PersonalGuitarCoach",
        "CFBundleName": "Personal Guitar Coach",
        "CFBundleDisplayName": "Personal Guitar Coach",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "1",
        "CFBundleDevelopmentRegion": "en",
        "CFBundleLocalizations": ["en", "uk"],
        "CFBundleIconFile": "AppIcon.icns",
        "LSMinimumSystemVersion": "14.0",
        "LSApplicationCategoryType": "public.app-category.education",
        "NSHighResolutionCapable": True,
        "NSMicrophoneUsageDescription": "Listen to your guitar for tuning and practice feedback.",
    }
    (contents / "Info.plist").write_bytes(plistlib.dumps(info))
    shutil.copy2(ROOT / "Resources/AppIcon.icns", resources / "AppIcon.icns")
    for catalog in sorted((ROOT / "Resources/Localization").glob("*.xcstrings")):
        run("xcrun", "xcstringstool", "compile", str(catalog), "--output-directory", str(resources))
    for directory in (ROOT / "Resources").iterdir():
        if directory.is_dir() and directory.name != "Localization" and not directory.name.endswith(".xcassets"):
            shutil.copytree(directory, resources / directory.name)
    for bundle in binary_directory.glob("*.bundle"):
        shutil.copytree(bundle, resources / bundle.name)
    run("codesign", "--force", "--sign", "-", "--options", "runtime", "--entitlements",
        str(ROOT / "App/PersonalGuitarCoach.entitlements"), str(staging))
    run("codesign", "--verify", "--strict", str(staging))
    run("swift", "run", "--package-path", "Packages/GuitarCoachCore", "ValidateLessonContent", str(resources / "Lessons"))
    run("python3", "Scripts/check_local_bundle.py", str(staging), "--configuration", args.configuration, capture=True)
    previous = Path(temporary) / "Previous.app"
    if app.exists():
        app.rename(previous)
    try:
        staging.rename(app)
    except BaseException:
        if previous.exists():
            previous.rename(app)
        raise
print(app)
if args.archive:
    archive = app.with_suffix(".zip")
    with tempfile.TemporaryDirectory(prefix=".archive-", dir=app.parent) as temporary:
        prepared = Path(temporary) / archive.name
        run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(prepared))
        os.replace(prepared, archive)
    print(archive)
