#!/usr/bin/env python3
"""Independent, read-only real-machine cross-check of InventoryVerify's JSON output."""
import json
import plistlib
import subprocess
import sys
import os
import stat
from datetime import datetime
from pathlib import Path

snapshot = json.loads(Path(sys.argv[1]).read_text())
items = snapshot["items"]
observations = snapshot["observations"]
errors = []
checks = []

def check(condition, description):
    (checks if condition else errors).append(description)

check(len({item["id"] for item in items}) == len(items), "Merged installation identities are unique")
for item in items:
    if item.get("path"):
        check(Path(item["path"]).exists(), "Reported payload exists: " + item["name"])
    if item.get("installedAt"):
        check(item.get("evidence", {}).get("installedAt", {}).get("confidence") == "verified", "Installation date has verified evidence: " + item["name"])
    if item.get("sizeBytes") is not None:
        check(item["sizeBytes"] >= 0 and "Logical" in item["sizeMetric"], "Size has explicit logical metric: " + item["name"])
        if "--sizes" in sys.argv and item.get("path"):
            seen, total = set(), 0
            for directory, _, filenames in os.walk(item["path"], followlinks=False):
                for filename in filenames:
                    info = os.lstat(os.path.join(directory, filename))
                    key = (info.st_dev, info.st_ino)
                    if stat.S_ISREG(info.st_mode) and key not in seen:
                        seen.add(key)
                        total += info.st_size
            check(item["sizeBytes"] == total, "Independent logical footprint matches: " + item["name"])

# Discover app bundles independently of the Swift scanner, stopping at bundle boundaries.
expected_apps = set()
visited = set()
def discover(directory, depth=0):
    if not directory.exists() or directory.resolve() in visited:
        return
    visited.add(directory.resolve())
    if directory.suffix.lower() == ".app":
        if (directory / "Contents/Info.plist").is_file():
            expected_apps.add(str(directory.resolve()))
        return
    if depth > 4:
        return
    for child in directory.iterdir():
        if child.name.startswith("."):
            continue
        if child.suffix.lower() == ".app" or child.is_dir() and not child.is_symlink():
            discover(child, depth + 1)
for root in [Path("/Applications"), Path.home() / "Applications"]:
    discover(root)
actual_apps = {item["path"] for item in observations.get("unmanaged", []) if item.get("path")}
check(expected_apps == actual_apps, f"Native apps match independent filesystem enumeration ({len(expected_apps)} bundles)")
for missing in sorted(expected_apps - actual_apps):
    print("Missing native payload:", missing)
for unexpected in sorted(actual_apps - expected_apps):
    print("Unexpected native payload:", unexpected)
for item in observations.get("unmanaged", []):
    path = Path(item["path"]) / "Contents/Info.plist"
    # Apple's parser handles binary plist revisions that Python's bundled parser may not.
    converted = subprocess.run(["/usr/bin/plutil", "-convert", "xml1", "-o", "-", str(path)], check=True, capture_output=True)
    info = plistlib.loads(converted.stdout)
    expected_version = info.get("CFBundleShortVersionString", info.get("CFBundleVersion"))
    check(item.get("version") == expected_version, "Native version matches Info.plist: " + item["name"])

formula_items = observations.get("homebrewFormula", [])
cask_items = observations.get("homebrewCask", [])
for prefix in [Path("/opt/homebrew"), Path("/usr/local")]:
    cellar = prefix / "Cellar"
    if cellar.exists():
        expected_kegs = {str(path.parent.resolve()) for path in cellar.glob("*/*/INSTALL_RECEIPT.json")}
        actual_kegs = {item["path"] for item in formula_items if item.get("path", "").startswith(str(cellar) + "/")}
        check(expected_kegs == actual_kegs, f"All installed keg paths match ({len(expected_kegs)} versions in {prefix})")
        for item in formula_items:
            receipt = Path(item["path"]) / "INSTALL_RECEIPT.json"
            if receipt.exists():
                check(item.get("version") == receipt.parent.name, "Formula version matches keg: " + item["name"])
                receipt_data = json.loads(receipt.read_text())
                if item.get("installedAt") and receipt_data.get("time"):
                    timestamp = datetime.fromisoformat(item["installedAt"].replace("Z", "+00:00")).timestamp()
                    check(abs(timestamp - receipt_data["time"]) < 1, "Formula installation time matches receipt: " + item["name"])

# These lists are captured separately with Homebrew's documented fast, read-only list path.
base = Path(sys.argv[1]).parent
formula_list, cask_list = base / "brew-formulae.txt", base / "brew-casks.txt"
if formula_list.exists():
    expected = set(formula_list.read_text().splitlines())
    actual = {item["packageID"] for item in formula_items}
    check(expected == actual, f"Formula names match brew list --formula -1 ({len(expected)} names)")
if cask_list.exists():
    expected = set(cask_list.read_text().splitlines())
    actual = {item["packageID"] for item in cask_items if item.get("path")}
    check(expected == actual, f"Cask tokens with existing payloads match brew list --cask -1 ({len(expected)} casks)")
for cask in cask_items:
    if cask.get("path"):
        same = [item for item in items if item.get("path") == cask["path"]]
        check(len(same) == 1 and same[0]["primarySource"] == "homebrewCask", "Cask merges with native discovery: " + cask["name"])
        receipt_path = cask.get("attributes", {}).get("Homebrew receipt")
        if receipt_path and cask.get("installedAt"):
            receipt_data = json.loads(Path(receipt_path).read_text())
            timestamp = datetime.fromisoformat(cask["installedAt"].replace("Z", "+00:00")).timestamp()
            check(abs(timestamp - receipt_data["time"]) < 1, "Cask installation time matches receipt: " + cask["name"])

print(f"{len(checks)} checks passed; {len(errors)} failed")
for message in checks:
    if message.startswith(("Native apps match", "All installed keg", "Formula names match", "Cask tokens", "Cask merges")):
        print("PASS:", message)
for message in errors:
    print("FAIL:", message)
sys.exit(bool(errors))
