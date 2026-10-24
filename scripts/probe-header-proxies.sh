#!/bin/bash
# Observational native AX comparison. No installed software, input-coordinate
# synthesis, removal, real preferences/cache or XCUITest outcome substitution.
set -euo pipefail
cd "$(dirname "$0")/.."
output="$PWD/build/verification/header-proxies"
mkdir -p "$output"
frameworks="${1:?Pass the Xcode Debug products directory containing MacventoryCore.framework}"
frameworks="$(cd "$frameworks" && pwd)"
if [[ ! -f "$frameworks/MacventoryCore.framework/Versions/A/MacventoryCore" ]]; then
  echo "Missing Debug framework: $frameworks/MacventoryCore.framework/Versions/A/MacventoryCore" >&2
  exit 1
fi
sources=()
for source in Sources/Macventory/*.swift; do
  [[ "$source" == Sources/Macventory/MacventoryApp.swift ]] || sources+=("$source")
done
sdk="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
xcrun swiftc -swift-version 6 -sdk "$sdk" \
  -module-cache-path "$PWD/.build/module-cache" \
  -F "$frameworks" -framework MacventoryCore -Xlinker -rpath -Xlinker "$frameworks" \
  "${sources[@]}" Diagnostics/HeaderProxyProbe.swift -o "$output/header-probe" \
  > "$output/compile.log" 2>&1
codesign --force --sign - "$output/header-probe"
# Record the actual dependency, including Xcode's absolute framework install name.
# LC_RPATH only resolves @rpath dependencies; DYLD_FRAMEWORK_PATH also overrides
# absolute framework dependencies for this standalone, ad-hoc signed executable.
otool -L "$output/header-probe" > "$output/linked-libraries.log"
xcrun --version > "$output/toolchain.log"
printf 'Compilation SDK: %s\n' "$sdk" >> "$output/toolchain.log"
xcrun swiftc --version >> "$output/toolchain.log"
sw_vers >> "$output/toolchain.log"
if xcrun --find xcodebuild >/dev/null 2>&1; then
  xcrun xcodebuild -version >> "$output/toolchain.log" 2>&1
fi
# Bound each independent probe so a native framework hang cannot consume the job.
python3 - "$output" "$frameworks" <<'PY'
from pathlib import Path
import json
import os
import subprocess
import sys
root = Path(sys.argv[1])
environment = os.environ.copy()
environment['DYLD_FRAMEWORK_PATH'] = sys.argv[2]
failures = []
for mode in ('keypath', 'custom', 'customized', 'inventory'):
    with (root / f'{mode}.log').open('w') as log:
        try:
            log.write(f'DYLD_FRAMEWORK_PATH={sys.argv[2]}\n')
            log.flush()
            result = subprocess.run([str(root / 'header-probe'), '--ui-testing', '--case=' + mode], env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=45)
            status = result.returncode
        except subprocess.TimeoutExpired:
            status = 'timeout'
    # A zero exit alone is insufficient: require main() and all six phases of
    # six actual header measurements. A dyld abort cannot masquerade as evidence.
    lines = (root / f'{mode}.log').read_text().splitlines()
    measurements = [json.loads(line) for line in lines if line.startswith('{')]
    complete = (any(line.startswith(f'case={mode} OS=') for line in lines)
                and sum(line.startswith('PHASE ') for line in lines) == 6
                and len(measurements) == 36
                and all('AXHitClass' in value and 'AXSortDirection' in value for value in measurements))
    if status != 0 or not complete:
        failures.append((mode, status, 'complete measurements=' + str(complete)))
    print(f'Native header probe {mode}: status={status}; inspect log, not an XCUITest pass.')
if failures:
    print('Native diagnostic failures:', failures)
    raise SystemExit(1)
PY
