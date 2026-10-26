# Native selection trace handoff validation

Date: 2026-10-25. Base: `4cafd6a0fef26b7bf2a321178de7bf5f720398f9` on `feature/unified-uninstall-and-inventory-health`. Proposed changes are local and uncommitted.

**COMMIT READY for the diagnostic handoff patch.** Hosted trace delivery and the real selection defect remain unvalidated. No production selection correction is proposed.

## Retained hosted evidence

Inspected full GUI job logs and both original xcresult archives:

- [Push 40228657255](https://github.com/vadimtanel/MacVentory/actions/runs/40228657255), GUI job 121276561305.
- [PR 40228660520](https://github.com/vadimtanel/MacVentory/actions/runs/40228660520), GUI job 121276697492.

The Push checkout is the base SHA. The PR artifact records checkout `88a5fb93d62ae205b8b2f3368c59b8187fffa5cd`, GitHub’s synthetic merge of the base feature SHA into `87de37f37a2c6e859174a27ce5a70a0c995fce26`. The fetched merge metadata confirms the feature parent and tree `45f0036d2547b045dd2425df1515646d7e69be8c`, identical to the local base tree. Distinguish the PR checkout SHA from its feature-head metadata. Native jobs succeeded. Each primary GUI suite executed 16 cases: 15 passed, 1 failed, 0 skipped, with two assertion failures in `testExplicitExecutionLevelsAndInteractiveVerification`. The final GUI jobs failed; the intermediate continue-on-error step does not establish success. Header proxy and independent pointer diagnostics passed.

The xcresult launch records supply `--ui-testing --qa-execution-levels --qa-selection-diagnostics --qa-selection-trace-file` followed by:

- Push: `/Users/runner/Library/Containers/org.vadimtanel.MacventoryUITests.xctrunner/Data/tmp/MacventorySelection-A2B383AD-D075-4D6D-9D66-E4A595F01286.jsonl`.
- PR: `/Users/runner/Library/Containers/org.vadimtanel.MacventoryUITests.xctrunner/Data/tmp/MacventorySelection-1F2BEFE5-26DF-489B-A764-E31500BA1A7A.jsonl`.

The retained application consoles contain:

- Push, PID 27192, 20:13:05.498951 UTC: `QA selection trace unavailable: require a fresh MacventorySelection-UUID.jsonl in this process temporary directory`.
- PR, PID 23261, 20:13:29.942899 UTC: the same message.

That message is emitted only after the isolated-mode/argument gate succeeds, the SwiftUI observer's `makeNSView` calls `start`, and `Session.init` returns nil. It is direct evidence of initialization rejection, not merely a missing attachment.

| Requested stage | Original hosted evidence |
| --- | --- |
| 1. Controller supplies arguments | Confirmed by xcresult launch records |
| 2–4. App receives flags, isolated mode, enabled gate | Confirmed by the app console branch reached only after these gates |
| 5. Observer creation/attachment | `makeNSView` reached; actual Reader attachment was not recorded after initialization failed |
| 6. Start attempts initialization | Confirmed by the app's rejection message |
| 7–8. Destination validation / exclusive create / first write | Initialization failed here; old code conflates validation and open failure |
| 9. Controller reads file | Generic old read assertion cannot distinguish missing, unreadable or empty |
| 10. Attach trace | Failed; no native-selection attachment in either failed-case manifest |

**Evidence limit:** neither archive records the application's actual canonical temporary root or the failed `open` errno. Thus stage 7 versus 8 cannot be recovered conclusively from these runs. The XCTest-container/app-temp mismatch is strongly supported, and is reproduced locally in separate processes, but is not retroactively proven to be the exact hosted guard failure. There is no evidence establishing a sandbox denial; App Sandbox remains disabled.

Archives verified against GitHub artifact metadata and ZIP integrity:

| Artifact | SHA256 |
| --- | --- |
| Push verification-ui 12612875128 | `bfa0114948a2e850b2ea9dd69bc5e904ec99267b30737cb548f18a64352696fe` |
| PR verification-ui 12613245009 | `0f75078dc44c1f40d2100dbedb6e0690a2022ce5d91f2c028ccbaa5ce22a1c77` |

Local retained evidence is under ignored `artifacts/trace-handoff-investigation/`, including the downloaded archives, original job logs, failed-case attachments, contract/build logs, startup receipts and final app trace.

## Proposed patch

Only an uppercase UUID nonce crosses the launch boundary (`--qa-selection-trace-id`). Both processes compile the same protocol and derive `/private/tmp/MacventorySelection-<effective uid>-<UUID>`. XCTest exclusively creates a fresh mode-0700 directory. The app verifies directory ownership/type/mode without following a link. Fixed-name files use descriptor-relative `openat`, `O_EXCL`, `O_NOFOLLOW`, `O_CLOEXEC` and mode 0600. Reads reject links, nonregular files, incorrect ownership/permissions, hard links, empty files and oversized data. No arbitrary destination path is accepted.

A bounded startup receipt records PID, actual argument-gate results, canonical `realpath` temporary root, process-local TMPDIR, fixed shared root and initialization outcome, independently of the SwiftUI observer. Initialization happens once from the existing AppModel startup after run-mode selection. It creates no views and changes no event/focus/selection behavior. Failures include operation, POSIX code and explanation; unsafe/unavailable receipt destinations also emit the error to the retained app console. The controller always attaches its own paths, validates the directory again, attaches available startup evidence, and distinguishes read errors, empty files, initialization failure and absent observer attachment. If the app never starts or the receipt destination itself is inaccessible, the controller reports that missing receipt explicitly and directs inspection to launch/console evidence rather than inventing an app error.

The existing 1 MiB observation bound and identifier/search hashing remain. Startup has at most bootstrap, ready and error records, each capped at 4 KiB, with a 16 KiB reader ceiling. Enabled requires isolated mode AND `--ui-testing` AND `--qa-selection-diagnostics`.

Exactly seven proposed files:

1. `Sources/Macventory/SelectionDiagnostics.swift`: shared secure transport, typed errors/startup receipt, observer-created event.
2. `Sources/Macventory/AppModel.swift`: one synthetic-gated bootstrap call.
3. `UITests/MacventoryUITests.swift`: nonce handoff, stage/read checks, retained attachments.
4. `Diagnostics/SelectionTraceContract.swift`: genuine parent/child regression, including different physical temporary roots and failure/disabled cases.
5. `scripts/generate-project.py`: compile the same diagnostic protocol into the independent UI runner, without loading the app/framework there.
6. `Macventory.xcodeproj/project.pbxproj`: matching deterministic generated source membership.
7. This validation report.

`InventoryView.swift`, all GUI test cases and their selected-row/Details identity assertions and interaction helpers are unchanged. No workflow, removal executor, helper policy or production signing change.

## Local validation

macOS 27.0.1; Command Line Tools with macOS 26.5 SDK for SwiftUI compilation. Full Xcode is absent.

- Final SwiftPM synthetic suite: 225 registered cases across 24 suites; **222 passed, 0 failed, 3 live integration cases skipped**. Live tests remain disabled (`MACVENTORY_LIVE_TESTS=0`).
- Final Debug and Release builds: passed. Only the existing `--build-system native` deprecation warning.
- Swift 6 standalone cross-process contract: passed. Child-only TMPDIR differs physically from the parent. Parent reads actual child-written startup/trace files. Covers synthetic gate, redaction, size bound, 0700/0600, exclusive creation, invalid nonce/name/directory modes, directory and file links, empty versus missing files, invalid file permissions, precise EEXIST receipt, preservation of existing target data, disabled tracing producing no files.
- Legacy implementation compiled from base HEAD: separate child with a different TMPDIR rejects the controller's destination before any file is created. Confirms a real gap in the old single-process contract.
- Final separately launched QA bundle: passed startup/trace/controller read. Receipt confirms isolated/enabled/ui-testing flags and canonical roots; observer creation and attachment, actual mouse delivery, search, binding assignment, observed selection and Details events are present. Final reviewed-build trace (`review-app-trace.jsonl`): 37 records, 25,673 bytes; SHA256 `3766a3a60d62f60ac4cef029ceae256124819f03bfc8cd103d11196f574cef65`. Synthetic names and identifiers are absent from the trace. One searched-result pointer click selected Example App and showed matching Details locally.
- A preliminary five-second background-only observer poll expired: startup was already ready; window construction/observer attachment occurred after normal app activation. The final check explicitly observed activation before requiring window events. This was a local harness timing limitation, not a suppressed passing check.
- The final GUI launch's app and controller canonical temp roots were both `/private/var/folders/yd/q93tytqx2695prp_m62s87s80000gn/T`; distinct-root coverage is the separate-process contract, not this GUI launch. Earlier Foundation `/var` versus Python `/private/var` spellings were aliases, not proof of different physical roots.
- Actual QA app with an intentionally preexisting test trace: startup reports `Create native-selection.jsonl: errno=17 (File exists)`; existing fixture bytes preserved; synthetic inventory still usable.
- Actual QA app without diagnostic flag: eight synthetic rows and QA protection visible; no startup or trace files created. All QA sessions quit normally.
- Project regeneration deterministic; `git diff --check` and Swift syntax parsing of the UI target passed. Full hosted Xcode target compilation, XCTest attachment delivery and macOS 26 behavior require the focused hosted run; syntax parsing is not XCUITest execution.

Reproduce the standalone contract from the repository root:

```sh
xcrun swiftc -swift-version 6 -parse-as-library \
  -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  -module-cache-path .build/module-cache \
  Sources/Macventory/SelectionDiagnostics.swift Diagnostics/SelectionTraceContract.swift \
  -o artifacts/trace-handoff-investigation/trace-contract
artifacts/trace-handoff-investigation/trace-contract
MACVENTORY_LIVE_TESTS=0 bash scripts/swift-tool.sh test
MACVENTORY_LIVE_TESTS=0 bash scripts/swift-tool.sh build
MACVENTORY_LIVE_TESTS=0 bash scripts/swift-tool.sh build -c release
```

All effects used fresh test-owned files/bundles, synthetic inventory and simulated removal. No real uninstall, installed software change, termination of a real installed application’s process, manager-state change, helper installation or activation occurred. Global TMPDIR and developer settings were not changed.

## Focused hosted plan — approval required, not executed

Workflow remains `.github/workflows/ci.yml`. A normal feature-branch push triggers BOTH full Push and PR workflows. Do not perform that push as the next diagnostic step without agreeing how to avoid those duplicate full GUI runs.

Proposed explicit one-time approval scope: commit this patch with message `fix: make QA selection trace handoff work across processes [skip ci]`, push the existing branch, then dispatch exactly one existing workflow at that exact remote SHA with `selection_scenario=isolated`. GitHub documents that the commit marker suppresses automatic Push/PR runs; those required checks remain Pending, not passed. No workflow is disabled or changed. See [GitHub skip-workflow documentation](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs).

1. Verify remote SHA and workflow `head_sha` equal the approved new commit; confirm no matching automatic runs exist. Do not cancel any existing run.
2. Dispatch the existing workflow once with ref `feature/unified-uninstall-and-inventory-health`, input `selection_scenario=isolated`. Its native prerequisite still runs SwiftPM, native app/helper builds, build-for-testing, hosted unit tests, packaging and artifact validation.
3. GUI runs only `MacventoryUITests/MacventoryUITests/testExplicitExecutionLevelsAndInteractiveVerification`. Existing sequence verification requires one executed case, zero skipped and no failure. Original selection and Details assertions stay intact. Preserve the real failure if selection still fails.
4. Download `verification-ui`, verify its digest, inspect `Selection-isolated.xcresult`, `gui-sequence.json`, `tested-head.txt` and original logs. Require retained `selection-controller.json`, `selection-startup.jsonl`, `native-selection.jsonl`. Check both canonical roots, bootstrap flags, trace.ready, observer/window attachment, mouse events and file/read outcomes. Report actual tests/assertions separately.
5. If trace delivery fails, diagnose the exact recorded stage before any broader GUI run. If trace succeeds but selection fails, classify event delivery, focus, binding assignment/reset, table reconstruction and XCTest behavior from the evidence; only then consider A/B/C/D/E paths.
6. After trace delivery is established, obtain approval for one `selection_scenario=full` dispatch at the same SHA to retain complete 16-case GUI, header proxy and pointer-diagnostic coverage. Focused success is not full CI validation. Normal Push/PR coverage remains configured for subsequent normally approved commits; Pending checks from the one-time skip are not bypassed and must be resolved before any eventual merge.

No commit, push, remote dispatch, workflow cancellation, merge, tag or release was performed. Remaining blockers: trustworthy hosted macOS 26 trace/attachment delivery, the actual hosted row-selection failure, full GUI validation after evidence collection, and the already outstanding real disposable uninstall/signed-helper/deployment/signing/Gatekeeper validations. Successful synthetic tests do not establish real uninstall correctness or release readiness.
