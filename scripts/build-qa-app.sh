#!/bin/bash
# Separate identity and persistent marker make QA isolation survive missing launch args.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh debug
qa_flavor="${1:-Identity}"
[[ "$qa_flavor" =~ ^[A-Za-z]+$ ]] || exit 1
qa_identifier="$(printf '%s' "$qa_flavor" | tr '[:upper:]' '[:lower:]')"
qa_directory="$PWD/build/Macventory $qa_flavor QA.app"
/usr/bin/ditto build/Macventory.app "$qa_directory"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier org.vadimtanel.Macventory.$qa_identifier-qa" "$qa_directory/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Macventory $qa_flavor QA" "$qa_directory/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :MacventoryQABundle bool true' "$qa_directory/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$qa_directory"
printf '%s\n' "$qa_directory"
