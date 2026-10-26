#!/bin/bash
# Verify the explicitly selected, preinstalled GitHub runner toolchain. No installs.
set -euo pipefail
mkdir -p build/verification
python3 - <<'PY'
import json, os
from pathlib import Path
# Explicit allowlist: never dump the environment or credentials into artifacts.
keys = ['RUNNER_NAME', 'RUNNER_ARCH', 'ImageOS', 'ImageVersion', 'GITHUB_RUN_ID',
        'GITHUB_RUN_ATTEMPT', 'GITHUB_JOB', 'GITHUB_SHA', 'SELECTION_SCENARIO', 'STARTUP_ARM']
Path('build/verification/runner-context.json').write_text(json.dumps(
    {key: os.environ.get(key, 'unset') for key in keys}, indent=2) + '\n')
PY
exec > >(tee build/verification/toolchain.log) 2>&1
printf 'Runner architecture: %s\n' "$(uname -m)"
sw_vers
printf 'Selected developer directory: %s\n' "${DEVELOPER_DIR:?Set DEVELOPER_DIR to the pinned Xcode}"
printf 'Installed Xcode applications:\n'
ls -d /Applications/Xcode*.app
xcodebuild -version
xcrun --find swift
xcrun swift --version
printf 'macOS SDK version: %s\n' "$(xcrun --sdk macosx --show-sdk-version)"
printf 'macOS SDK path: %s\n' "$(xcrun --sdk macosx --show-sdk-path)"
[[ "$(uname -m)" == arm64 ]] || { echo 'Expected a native arm64 runner'; exit 1; }
[[ "$(sw_vers -productVersion)" == 26.* ]] || { echo 'Expected macOS 26'; exit 1; }
[[ "$(xcodebuild -version | head -n 1)" == 'Xcode 26.5' ]] || { echo 'Expected Xcode 26.5'; exit 1; }
[[ "$(xcrun swift --version)" == *'Swift version 6.3'* ]] || { echo 'Expected bundled Swift 6.3'; exit 1; }
[[ "$(xcrun --sdk macosx --show-sdk-version)" == 26.5 ]] || { echo 'Expected macOS SDK 26.5'; exit 1; }
