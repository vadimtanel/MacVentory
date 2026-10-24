#!/bin/bash
# Observational native AX comparison. No installed software, input-coordinate
# synthesis, removal, real preferences/cache or XCUITest outcome substitution.
set -euo pipefail
cd "$(dirname "$0")/.."
output="$PWD/build/verification/header-proxies"
mkdir -p "$output"
frameworks="${1:?Pass the Xcode Debug products directory containing MacventoryCore.framework}"
sources=()
for source in Sources/Macventory/*.swift; do
  [[ "$source" == Sources/Macventory/MacventoryApp.swift ]] || sources+=("$source")
done
xcrun swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -F "$frameworks" -framework MacventoryCore -Xlinker -rpath -Xlinker "$frameworks" \
  "${sources[@]}" Diagnostics/HeaderProxyProbe.swift -o "$output/header-probe" \
  > "$output/compile.log" 2>&1
codesign --force --sign - "$output/header-probe"
# Bound each independent probe so a native framework hang cannot consume the job.
python3 - "$output" <<'PY'
from pathlib import Path
import subprocess
import sys
root = Path(sys.argv[1])
failures = []
for mode in ('keypath', 'custom', 'customized', 'inventory'):
    with (root / f'{mode}.log').open('w') as log:
        try:
            result = subprocess.run([str(root / 'header-probe'), '--ui-testing', '--case=' + mode], stdout=log, stderr=subprocess.STDOUT, timeout=45)
            status = result.returncode
        except subprocess.TimeoutExpired:
            status = 'timeout'
        if status != 0:
            failures.append((mode, status))
    print(f'Native header probe {mode}: status={status}; inspect log, not an XCUITest pass.')
if failures:
    print('Native diagnostic failures:', failures)
    raise SystemExit(1)
PY
