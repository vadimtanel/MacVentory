# v1.1.0 stabilization: documentation audit and selection evidence

26 October 2026, Asia/Jerusalem. **Local review checkpoint; no new commit, push, PR, dispatch, merge, tag or release.** Proposed message: `test(ui): isolate selection stages and make GUI CI fail explicitly`.

## Branch preservation

The initial working tree was clean on existing `release/v1.1.0-stabilization` at `3c99886e9fe2f625279e9fe75aab83dc9274e0c1`. Local/remote stabilization refs both identified this documentation commit; local/remote-tracking/advertised remote main were checked separately. Only one worktree exists, on stabilization.

The documentation commit's parent is `a5a66efcaf2f1b06c3f32bb104e6125239f831c9`, exactly the verified `origin/main` baseline. With explicit approval, only local `refs/heads/main` was restored using a compare-and-swap ref update from `3c99886` to `a5a66ef`. The checked-out stabilization ref, original documentation commit, upstream and both remote branches were preserved. No reset/rebase/history rewrite or discarded work was used. New patch changes remain unstaged/uncommitted on stabilization.

## Independent audit of the documentation commit

The exact `3c99886` diff against its parent contains **19 Markdown files only**, with no source, dependency, workflow, signing or Cask change. All 19 changed documents were inspected, including current content and historical context:

| Files | Audit result |
|---|---|
| `README.md`, `CHANGELOG.md`, `Docs/INSTALLATION.md`, `Docs/RELEASING.md` | Upcoming 1.1.0/build108, four expected artifact names, durable release links, DMG/ZIP/Homebrew/updating/checksums and ad-hoc/Gatekeeper limits agree. Existing v1.0.0 history and application-management baseline are distinguished from new features. |
| `Docs/CI.md`, `Docs/VERIFICATION.md`, `Docs/RELEASE_DOCUMENTATION_REVIEW.md` | Local/synthetic/hosted/real-effect evidence is separated. Recorded native success is not a full GUI pass. The review was accurate as a dated pre-push record; later remote/run state now needs current-state updates. |
| `Docs/UNINSTALL.md`, `SECURITY.md`, `Docs/SOURCE_SUPPORT.md`, `Docs/ARCHITECTURE.md`, `Docs/TECHNICAL_CORRECTIONS.md`, `SPEC.md` | Per-installation Direct/Interactive/Guided support, independent protection, limited bundle scope, current manager/version restrictions, helper authority, optional official-link networking and real-effect limitations agree with implementation. No universal automatic removal claim. |
| `CONTRIBUTING.md`, `Docs/SETTINGS.md`, `Fixtures/README.md` | Meaningful synthetic QA, default-off/manual personal discovery and fixture boundaries remain explicit. |
| `Docs/CHECKPOINT.md`, `Docs/GUI_QA.md`, `Docs/INVENTORY_AUDIT.md` | Only historical notices/current links were added; recorded bodies/builds/counts are preserved. |

Metadata remains **1.1.0 / build 108 / configured macOS 13.0**, without another increment. Historical v1.0.0 fixtures, validation/build identifiers and notes were not relabeled. Branding/screenshots/LICENSE/NOTICE are unchanged. All 19 documents parsed; the unchanged publication preflight passed with **147 inputs, zero findings** before this patch. Relative links/assets/heading targets were checked separately. No unnecessary product-document rewrite was needed. Only current CI/release/verification sections are updated for the proposed workflow, added regression and newly observed remote run; the original documentation-review record remains historical.

## Hosted evidence actually inspected

| Run / source SHA | Primary GUI result | Observation |
|---|---|---|
| [40306934877](https://github.com/vadimtanel/MacVentory/actions/runs/40306934877), `de9c53fa097f0b180bc857be75d22d00c1b859d6` | 16 started, 15 passed, 1 failed, 0 skipped | Original execution-level selection failure |
| [40309598774](https://github.com/vadimtanel/MacVentory/actions/runs/40309598774), `a5a66efcaf2f1b06c3f32bb104e6125239f831c9` | Same 15/16, same failure | Info.plist version-only change did not cause/fix it |
| [40316125739](https://github.com/vadimtanel/MacVentory/actions/runs/40316125739), `3c99886e9fe2f625279e9fe75aab83dc9274e0c1` | Same 15/16, same failure | Existing stabilization push, completed before this investigation; not dispatched here |

For the two cited runs, public metadata and raw logs establish native pipeline success, primary `testExplicitExecutionLevelsAndInteractiveVerification` failure, and passing independent header diagnostics. Native success does not override overall failure. The primary log ends `** TEST FAILED **`; the successful-looking GitHub step conclusion was caused by `continue-on-error`, not a successful XCTest suite. The later sequence/report gate correctly failed the old job.

The complete GUI ZIP for run 40309598774 (artifact `12644814304`) was downloaded and checked against GitHub's SHA-256 `abbbb02de20cd1c5884cfcd05f99c7a6e57c7b948f26eb0e6fe51ce7fc9a43c0`; ZIP integrity passes (2,154 entries). Referenced startup/controller/native attachments, full AX hierarchies, pointer geometry, test activity records/log timestamps and screen recording were extracted/inspected. Small records from artifacts `12644615724` and `12648510703` were retrieved by ZIP byte ranges with entry-size/CRC checks for comparison; they are not described as independently full-ZIP-hash-verified downloads.

**Tool limit:** `xcrun --find xcresulttool` fails because this Mac has Command Line Tools, not full Xcode. Therefore local inspection used the existing zstd-decoding method to read actual xcresult object/attachment payloads. This is raw hosted evidence, but it is **not an xcresulttool execution**. The intact full archive is preserved. The proposed CI exports summaries, test tree, activities and attachments using the runner's actual `xcresulttool`; that new export step still requires hosted validation.

Ignored evidence remains under `artifacts/v110-stabilization/`, including the complete ZIP, extracted records, attachment hashes, both comparison runs, raw logs, failed-screen capture and local test/build logs. Signed temporary download URLs and hosted paths remain ignored, not public documentation links/assets.

## Confirmed failure boundary

All three native traces contain the same 60-event pattern. Controller directory open, startup read and trace read succeeded. Startup reached `trace.ready` in isolated `--ui-testing` mode. The final query token corresponds to `Example App`; exactly one row remained before the click.

| Sequence | Native observation | SwiftUI/application observation |
|---|---|---|
| 58: mouse down | Name-text center at screen `(346,212)`, window `(346,479)`. `hitTest` resolves the real Name cell hosting view; `rowAtPoint=0`, one row, no native selection. Search field editor is first responder. | Expected filtered installation token remains present; binding is nil. |
| 59: search editing ends | `NSControlTextDidEndEditingNotification`; the same table temporarily reports `selectedRows=[0]`. | No `binding.set` or `selection.observed` event. |
| 60: next main turn | First responder is the same native outline; `selectedRows=[]`, `rowAtPoint=0`. | Binding remains nil; no Details appearance. |

In run 40309598774 these snapshots occur at uptimes **705.157070**, **705.164974**, **705.246952** seconds; earlier/later runs repeat the ordering. XCTest sends the click at test time about 15.2 seconds, then waits for selection/Details and fails. AX hierarchy shows the correct visible row unselected and no Details title; the recording independently shows no selection highlight/Details. There are no `native.selectionChanged`, `binding.set`, `selection.observed`, `selection.clear` or `details.appeared` events anywhere in these traces. Table identity does not change during the failed interaction; the filtered row survives.

**Established:** native selection is transiently lost while leaving search editing, before propagation into the SwiftUI binding. This is not merely a false XCTest selection predicate, wrong row/name, filter dropping the target, application selection-clear callback or post-selection Details/table reconstruction. No evidence attributes it to version metadata.

**Not established:** which private AppKit/SwiftUI/XCTest implementation path drops that transient selection, whether extra XCTest activation causes it, or whether changing the row gesture fixes the hosted runtime. The observational monitor predicts hit routing and samples state; it cannot prove execution of private mouse handlers or the complete mouse-up path. Local macOS 27 evidence from earlier investigations succeeds where hosted macOS 26 fails, so it cannot certify the affected runtime. No speculative production selection setter, responder override, private delegate replacement or uninstall-rule change is introduced.

## Proposed local correction and regression architecture

- Name cells get stable `inventory.name.<installation-id>` identifiers in both native table variants. These are accessibility identifiers only; selection/ownership/removal behavior is unchanged.
- The test resolves the exact native row from that identified Name cell and invokes **one native row click**. It verifies the row's center and name are in the viewport/window, retains geometry/hierarchy and removes redundant foreground reactivation. No arbitrary delay, extra click, Tab workaround, binding injection or retry is added. This is a candidate supported interaction change, not proof of a repaired product/framework.
- Separate stage assertions require query acknowledgment, identified visible row, correct native mouse hit, native selection notification, exact binding update/observed state, rendered selected-row/Details identity and matching management title. Assertions read the existing private synthetic trace; they cannot set selection. Native pre-click selected state and previously observed SwiftUI identity are checked independently: neither already-selected state must emit a redundant change event. Native/Details identity remains mandatory after the click. Failed stages retain hierarchy/screenshot and the original startup/controller/native teardown attachments.
- `testSearchSelectionAndDetailsContract` exercises two search-to-selection transitions without opening management. The original execution-level scenario retains all Direct/Interactive/Guided/Protected, confirmation, waiting/verification and dismissal assertions. All **16 original cases remain**, plus this regression (**17 primary cases**). Isolated runs include the original case and new regression; no failing case is removed or skipped.
- The primary CI step loses `continue-on-error`. A small testable wrapper preserves Xcode/tee exits, requires actual case evidence and records requested scenario, checked-out SHA and raw exit statuses. Zero process exit without valid tests/result bundle is rejected. A finalized failure permits separate evidence/diagnostics; interrupted execution does not.
- Stabilization-branch pushes are excluded from automatic CI so pushing the candidate cannot start a full GUI run before approval. The authorized cycle dispatches only `isolated`; any later `full` run requires separate approval.
- The verifier uses an explicit original-case list plus the new test, checks source coverage, rejects failed/skipped/missing/duplicate/incomplete cases and mixed terminal markers, and validates requested SHA/scenario. Reporting never substitutes native success for GUI success. Evidence export and full-scenario header/pointer diagnostics remain separately visible and required. Failures are errors, not warnings.

Changed implementation/test/CI paths: `Sources/Macventory/InventoryTable.swift`, `Sources/Macventory/InventoryView.swift`, `UITests/MacventoryUITests.swift`, `.github/workflows/ci.yml`, `scripts/run-ui-tests.sh`, `scripts/verify-ui-selection-run.py`, `Tests/CI/test_gui_reporting.py`. Current-state documentation changes are `Docs/CI.md`, `Docs/RELEASING.md`, `Docs/VERIFICATION.md` and this report. No uninstall effect/authorization source, signing/dependency/version configuration or separate Tap file changes.

## Local validation and next gate

- Existing synthetic Swift suite: **225 registered tests / 24 suites**, 222 passed and three intentional live-test skips, no failure. Initial restricted launch could not create SwiftPM's sandbox; the approved rerun retained SwiftPM sandboxing outside that execution restriction. No live integration/effect was invoked.
- Application build after the two identifier additions: **PASS**. The existing native-build-system deprecation warning remains.
- **11 Python reporting regression tests pass**, including 17 separate missing-case subchecks, failure/skip/duplicate/incomplete/mixed-terminal controls, false process success, Xcode/tee exit propagation, interrupted/missing-bundle guards, SHA/scenario mismatch, original-plus-new coverage, focused ordering and final job failure for each failed/skipped required step. They use fake Xcode/git/log effects in disposable temporary fixtures, not real apps.
- UI Swift syntax parsing, the Foundation predicate closure under Swift 6/warnings-as-errors, workflow YAML parsing, extracted shell syntax and Git whitespace checks pass. Full UI XCTest type checking/execution is **not available locally**; parsing is not a substitute. No new manual GUI or packaged-app claim is made.
- Final publication preflight: **150 inputs, zero findings**. All **36 Markdown documents** parse; **151 local references and five heading fragments** resolve. Historical bodies and the exact 19-file original commit remain preserved. Whitespace, empty index and local/remote branch SHA checks pass. No source package, DMG/ZIP, tag or release is generated by this work.

**Reviewable candidate for a focused validation commit; not a verified permanent selection fix.** The actual failure boundary and CI reporting defect are established, but the native-row interaction change and new XCTest/export APIs still need compilation/execution with the pinned hosted Xcode. Do not label this a completed production root-cause fix or a release-ready patch. A precise internal-runtime attribution would require the affected host's controlled interaction comparison, not speculation from a timing sample.

After separate approval of commit/push/dispatch, perform exactly one focused `isolated` run on the approved SHA. Require both cases and all seven selection/management stages to pass, retained trace/export evidence and honest workflow conclusion. Only then run one `full` scenario on the exact same final candidate SHA, requiring native builds/units/packages/checksums, all 17 primary cases, exports and independent header/pointer diagnostics. Any further code/doc change requires final-SHA validation again. Do not repeat full runs without a demonstrated reason. No remote work is authorized by this report.

**RELEASE READY: no.** Real destructive provider/Trash/vendor/Steam/Store/Force Quit behavior, signed-helper deployment, minimum-OS runtime, clean-machine Gatekeeper and full VoiceOver remain unverified. No real installed software, manager state, process, user data or helper was modified, removed, Force Quit or activated in this stabilization task.
