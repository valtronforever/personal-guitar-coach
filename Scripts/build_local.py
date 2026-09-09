#!/usr/bin/env python3
"""Build the native app with SwiftPM, compile catalogs, and ad-hoc sign its bundle."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--configuration", choices=["debug", "release"], default="debug")
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
if app.exists():
    shutil.rmtree(app)
contents = app / "Contents"
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
    "LSMinimumSystemVersion": "14.0",
    "LSApplicationCategoryType": "public.app-category.education",
    "NSHighResolutionCapable": True,
    "NSMicrophoneUsageDescription": "Listen to your guitar for tuning and practice feedback.",
}
(contents / "Info.plist").write_bytes(plistlib.dumps(info))
for catalog in sorted((ROOT / "Resources/Localization").glob("*.xcstrings")):
    run("xcrun", "xcstringstool", "compile", str(catalog), "--output-directory", str(resources))
for directory in (ROOT / "Resources").iterdir():
    if directory.is_dir() and directory.name != "Localization" and not directory.name.endswith(".xcassets"):
        shutil.copytree(directory, resources / directory.name)
for bundle in binary_directory.glob("*.bundle"):
    shutil.copytree(bundle, resources / bundle.name)
run("codesign", "--force", "--sign", "-", "--options", "runtime", "--entitlements",
    str(ROOT / "App/PersonalGuitarCoach.entitlements"), str(app))
run("codesign", "--verify", "--strict", str(app))
print(app)
