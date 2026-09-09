#!/usr/bin/env python3
"""Type-check UI-test APIs using the selected Xcode SDK; this does not execute UI tests."""
import os
from pathlib import Path
import platform
import subprocess

root = Path(__file__).resolve().parents[1]
environment = os.environ.copy()
environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
platform_path = Path(subprocess.check_output(
    ["xcrun", "--sdk", "macosx", "--show-sdk-platform-path"], env=environment, text=True).strip())
subprocess.run([
    "xcrun", "--sdk", "macosx", "swiftc", "-typecheck", "-swift-version", "6",
    "-target", f"{platform.machine()}-apple-macosx14.0",
    "-F", str(platform_path / "Developer/Library/Frameworks"),
    "-I", str(platform_path / "Developer/usr/lib"),
    *map(str, sorted((root / "Tests/UITests").glob("*.swift"))),
], cwd=root, env=environment, check=True)
print("UI-test sources type-check; UI execution is a separate check.")
