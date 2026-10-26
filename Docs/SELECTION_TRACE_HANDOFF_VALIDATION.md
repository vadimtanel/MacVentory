# Hosted sandbox selection trace handoff correction

Date: 2026-10-26. Base: `1f534fbfc774e5a42456570ec59f2e7a3671e32c` on `feature/unified-uninstall-and-inventory-health`.
This four-file correction is local and uncommitted.

**COMMIT READY for controlled isolated diagnostic validation. NOT MERGE READY.**
The original selection test has not passed on this revision. No selection fix is claimed.

## Confirmed hosted boundary

[Run 40294805016](https://github.com/vadimtanel/MacVentory/actions/runs/40294805016), attempt 1, used this base SHA with `selection_scenario=isolated`.
Native builds, synthetic tests, hosted Xcode units, release packaging and artifact validation passed.
The original `testExplicitExecutionLevelsAndInteractiveVerification` executed once and failed before `app.launch()`:
`Create private trace directory: errno=1 (Operation not permitted)` at `SelectionDiagnostics.swift:28`.

The generated xcent used to sign the UI runner contains:

- `com.apple.security.app-sandbox = 1`
- `com.apple.security.temporary-exception.files.absolute-path.read-only = ["/"]`

Controller mkdir is outside its writable container. The exception grants reads, not creation, append or deletion.
[Apple documents this read-only exception](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html).
Actual reads are tested independently below rather than inferred from successful app writes.

The failed xcresult retained only a screen recording. No startup, native trace or controller attachment was created.
No mouse, responder, table-selection or SwiftUI-binding observations were captured.
This is a diagnostic bootstrap failure, not an established cause of the original selection regression.

Earlier [Push 40228657255](https://github.com/vadimtanel/MacVentory/actions/runs/40228657255) and
[PR 40228660520](https://github.com/vadimtanel/MacVentory/actions/runs/40228660520) each ran 16 original GUI cases:
15 passed, 1 failed, 0 skipped. Header/pointer diagnostics passed on those earlier revisions.
Those historical results do not validate the current revision.

Original technical findings, unsanitized paths, logs and archives remain in ignored
`artifacts/trace-handoff-investigation/` and `artifacts/hosted-isolated-1f534fb/`.
The previous version of this report is preserved in
`artifacts/sandbox-handoff-correction/previous-handoff-validation.md`.

## Four-file correction

1. `Sources/Macventory/SelectionDiagnostics.swift`: the synthetic app exclusively creates the private directory, startup receipt and trace. Normal-termination cleanup checks directory identity and removes only the two fixed validated filenames and directory; it never recursively removes unknown contents.
2. `UITests/MacventoryUITests.swift`: before launch, the runner only derives the nonce destination. Teardown opens and reads it, attaches startup and native trace independently, and always attaches controller evidence including typed open/read failures. All attachments retain `keepAlways`. Only after capture does the synthetic app receive normal Quit; teardown verifies its directory is gone.
3. `Diagnostics/SelectionTraceContract.swift`: separate app-bootstrap writer and sandboxed controller reader, denied-write negative controls, real termination-observer cleanup, security and disabled-mode regressions. Added hard-link, replaced-directory and unknown-file cleanup coverage.
4. This report.

Only an uppercase UUID nonce crosses the launch boundary. The fixed destination remains
`/private/tmp/MacventorySelection-<effective uid>-<UUID>`; no arbitrary destination is accepted.
Exclusive creation, 0700 directories, 0600 files, descriptor-relative no-follow access, ownership/type/mode checks,
single-link file checks, bounded nonempty reads, 1 MiB trace limit and bounded startup records remain.
Search/identifier hashing and isolated-mode AND `--ui-testing` AND `--qa-selection-diagnostics` gating remain.

The runner never creates or deletes evidence at that destination. A crash or failed normal Quit may leave
test-owned evidence; teardown fails explicitly rather than pretending cleanup succeeded.
No app-wide entitlements, production signing, workflow, uninstall executor or authorization policy changes.
No selection/focus/table behavior during the test, interaction helper or original GUI test assertion changes.

## Local results and limits

Host: macOS 27.0.1, Command Line Tools, macOS 26.5 SDK for SwiftUI. Full Xcode is absent.

- Swift 6 contract compiled with warnings treated as errors: PASS.
- Separate writer creates/writes; independent controller opens/reads startup and trace: PASS.
- Controller runs under a kernel-enforced sandbox-exec profile denying all filesystem writes.
  It reads the app-created 0700 directory and 0600 files, while mkdir/append/unlink return EPERM and evidence remains unchanged.
  This models the hosted runner's relevant read-only filesystem boundary with stricter write denial
  (no writable private container). It is not the complete entitlement-generated XCTest sandbox.
  No application entitlement was added or expanded.
- Contract retains synthetic gating, redaction, size bound, exclusive directory/file creation, invalid nonce/name/mode,
  directory/file symlink refusal, empty/missing reads and disabled-mode checks. It verifies hard-link refusal,
  existing target preservation, replaced-directory cleanup refusal, unknown-file preservation, empty-directory cleanup
  and app-owned termination cleanup.
- Two preliminary contract attempts failed at the former assumption that FileManager temporary roots must differ:
  macOS 27 ignored the child's TMPDIR override in FileManager.temporaryDirectory.
  The corrected contract verifies physically distinct configured roots, records the actual Foundation roots,
  and checks transport independently of either root. Original GUI assertions are unchanged.
- Actual separately built QA-marked app: PASS. Eight synthetic rows and simulation protection observed.
  A separate sandboxed reader captured startup bootstrap/trace.ready and native events
  trace.started, observer.created, swiftUI.updated, window.attached and tableProbe.attached.
  Reader mkdir/append negative controls returned EPERM.
  Startup: 427 bytes, SHA256 `952122d93a9ccede864e2b22dbfdde8c1dcff004c662606876d7716f778ea3f0`.
  Native trace: 1,465 bytes, SHA256 `75de2b57e0c7b224707a52ec2f5a73a69da7c669e3544cc67e6214b431447a27`.
  Normal app-menu Quit exited 0 and removed the trace directory. This was not the original hosted selection test.
- Existing SwiftPM synthetic tests: 225 registered across 24 suites; **222 passed, 0 failed, 3 intentional live-test skips**.
- Debug and Release Macventory builds: PASS.
- UI Swift syntax parse: PASS. Full Xcode type checking and XCTest attachment execution remain unvalidated.
- Publication preflight: zero findings. Whitespace check: PASS.

SwiftPM and sandbox-exec initially could not create child sandboxes inside the restricted execution tool.
Successful reruns lifted that tool restriction while retaining SwiftPM sandboxing and applying the reader sandbox.
No macOS protection was disabled. Builds retain the existing native-build-system deprecation warning.

Evidence is retained in ignored `artifacts/sandbox-handoff-correction/`: contract/build/test logs,
actual startup/native/controller bytes, QA session identity and this report's previous version.
Only synthetic fixtures were used. No real installed software, manager state, process or personal data was modified
or removed. No privileged helper was installed or activated.

## Reproduce the local contract

From the repository root:

```sh
mkdir -p artifacts/sandbox-handoff-correction
xcrun swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  -module-cache-path .build/module-cache \
  Sources/Macventory/SelectionDiagnostics.swift Diagnostics/SelectionTraceContract.swift \
  -o artifacts/sandbox-handoff-correction/trace-contract
artifacts/sandbox-handoff-correction/trace-contract
MACVENTORY_LIVE_TESTS=0 bash scripts/swift-tool.sh test
MACVENTORY_LIVE_TESTS=0 bash scripts/swift-tool.sh build --product Macventory
MACVENTORY_LIVE_TESTS=0 bash scripts/swift-tool.sh build -c release --product Macventory
python3 scripts/review-publication.py
```

The contract fails if its sandbox cannot execute; it does not silently skip validation.

## Prepared hosted plan — approval required, not executed

Recommended message: `fix: respect hosted runner sandbox in QA trace handoff [skip ci]`

After explicit approval, commit only the four reviewed files, push and verify the exact remote SHA.
The marker suppresses automatic Push/PR workflows; it does not establish passing CI.
Dispatch exactly one existing `.github/workflows/ci.yml` on the feature branch with `selection_scenario=isolated`.
Do not start a full GUI workflow at this stage.

Require workflow head_sha, tested-head.txt and scenario agreement, plus actual execution of
`MacventoryUITests/MacventoryUITests/testExplicitExecutionLevelsAndInteractiveVerification`.
Inspect the complete xcresult for synthetic app launch and retained attachments:

- `selection-controller.json`: successful open/startupRead/traceRead and controller process evidence.
- `selection-startup.jsonl`: isolated/enabled flags, app process evidence, bootstrap and trace.ready.
- `native-selection.jsonl`: observer.created, window.attached, actual mouse events,
  responder snapshots, native table state and SwiftUI binding observations.
- Actual sequence counts and successful app-owned cleanup.

Hosted open/read/attachment success is a gate, not an assumption. If it fails, use the typed failure and console
evidence before choosing another transport. If selection still fails after trace capture, analyze event routing,
responder focus, native rows and binding observations before changing selection behavior.

After the selection issue is resolved, separately approve `selection_scenario=full` on the final source SHA.
Before merge, require native/hosted units, all 16 original GUI tests without missing/skipped/weakened cases,
independent pointer diagnostics, release packaging and artifact validation.
Synthetic CI does not establish real uninstall correctness or signed-helper deployment safety.
