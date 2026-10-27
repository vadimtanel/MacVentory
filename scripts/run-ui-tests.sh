#!/bin/bash
# Preserve the actual Xcode/tee exit status and require real primary case results.
# No retries, dispatch, live effects or outcome substitution.
set -euo pipefail
scenario="${SELECTION_SCENARIO:?Set SELECTION_SCENARIO}"
startup_arm="${STARTUP_ARM:-suite}"
selected=MacventoryUITests/MacventoryUITests
target=testExplicitExecutionLevelsAndInteractiveVerification
filters=("-only-testing:$selected/$target")
result_bundle="build/verification/Selection-$scenario.xcresult"
case "$scenario" in
  startup)
    method="$(python3 scripts/verify-ui-selection-run.py startup /dev/null --startup-arm "$startup_arm" --print-startup-method)"
    filters=("-only-testing:MacventoryUITests/MacventoryStartupDiagnostics/$method") ;;
  isolated) filters+=("-only-testing:$selected/testSearchSelectionAndDetailsContract") ;;
  paths) filters=("-only-testing:MacventoryUITests/MacventorySelectionPathDiagnostics") ;;
  after-layout) filters+=("-only-testing:$selected/testDetailsActionsStayVisibleAcrossLayoutsAndLongMetadata") ;;
  after-headers) filters+=("-only-testing:$selected/testAllNativeHeaderSortsPreserveSelection") ;;
  full) filters=("-only-testing:$selected"); result_bundle=build/verification/UITests.xcresult ;;
  *) exit 2 ;;
esac
[[ "$scenario" == startup || "$startup_arm" == suite ]] || { echo 'Startup arm cannot change primary coverage' >&2; exit 2; }
mkdir -p build/verification
printf '%s\n' "$scenario" > build/verification/selection-scenario.txt
printf '%s\n' "$startup_arm" > build/verification/startup-arm.txt
git rev-parse HEAD > build/verification/tested-head.txt
expected_sha="${TESTED_SHA:-$(git rev-parse HEAD)}"
[[ "$(cat build/verification/tested-head.txt)" == "$expected_sha" ]] || { echo 'Checkout SHA mismatch' >&2; exit 1; }
set +e
xcodebuild -project Macventory.xcodeproj -scheme Macventory \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData \
  -resultBundlePath "$result_bundle" "${filters[@]}" -parallel-testing-enabled NO \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG QA_SELECTION_NO_ITEM_ACTIONS' \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test \
  2>&1 | tee build/verification/xcode-ui-tests.log
results=("${PIPESTATUS[@]}")
set -e
# A finalized failing run may be diagnosed; an interrupted desktop may not.
finalized=false
if [[ "${results[0]}" == 0 || "${results[0]}" == 65 ]] && \
   [[ -f "$result_bundle/Info.plist" ]] && \
   grep -Eq '^\*\* TEST (EXECUTE )?(SUCCEEDED|FAILED) \*\*$' build/verification/xcode-ui-tests.log; then
  printf 'primary_finished=true\n' >> "${GITHUB_OUTPUT:?}"
  finalized=true
fi
set +e
python3 scripts/verify-ui-selection-run.py "$scenario" build/verification/xcode-ui-tests.log \
  --expected-sha "$expected_sha" --tested-head build/verification/tested-head.txt \
  --recorded-scenario build/verification/selection-scenario.txt \
  --startup-arm "$startup_arm" --recorded-startup-arm build/verification/startup-arm.txt \
  > build/verification/gui-sequence.json
sequence_exit=$?
set -e
cat build/verification/gui-sequence.json
printf '{"xcode_exit":%s,"tee_exit":%s,"sequence_exit":%s,"finalized":%s}\n' \
  "${results[0]}" "${results[1]}" "$sequence_exit" "$finalized" > build/verification/gui-exit-status.json
if [[ "${results[0]}" != 0 ]]; then exit "${results[0]}"; fi
if [[ "${results[1]}" != 0 ]]; then exit "${results[1]}"; fi
[[ "$finalized" == true ]] || { echo 'Primary Xcode execution/result bundle did not finalize' >&2; exit 1; }
exit "$sequence_exit"
