# Missing inventory window: startup investigation and stabilization gates

26 October 2026. Local, uncommitted observations/test patch on `release/v1.1.0-stabilization`, based on `343ac0f2f8202d2ad81c3df60ab0dc0b24767fe3`. No new commit, push or hosted dispatch is authorized by this report. All 17 primary GUI cases, including the selection regression, remain required and unchanged in scope.

## Established boundary

In [run 40322862024](https://github.com/vadimtanel/MacVentory/actions/runs/40322862024), both requested isolated cases launched a process, completed XCTest automation setup/idle waits and executed the existing immediate `activate()`. Neither discovered an application window during the existing 10-second wait. The original case failed at test time 13.59 seconds; the new regression failed at 10.86 seconds. Both failed in the launch helper before sidebar, search, selection, Details or management assertions. This run does not evaluate the selection change.

The app-created startup attachments for PIDs 2748 and 2994 contain `bootstrap` with isolated/UI-testing/diagnostics enabled, then `trace.ready`. Each native trace contains exactly one `trace.started` event. Both controllers successfully opened/read the correct private session directory. Therefore missing evidence is not a handoff/path failure. **`trace.ready` is emitted near the beginning of AppModel initialization; it does not prove that initialization completed.** No `observer.created`, `swiftUI.updated`, `window.attached` or `tableProbe.attached` follows.

The exported xcresult summary and activities agree with the raw log: 2 started, 0 passed, 2 failed, 0 skipped; Xcode exit 65. The other two assertion failures are teardown's missing-table-observer checks, downstream of the primary window failure. Both AX hierarchies and archived `XCElementSnapshot` records show the application/menu bar without an application window. The retained recordings show the Macventory menu bar and Dock, with no visible inventory window throughout the window wait. Frames were extracted for visual comparison; exported “UI Snapshot” binary attachments are accessibility snapshots, not PNG screenshots. The app responded to normal Command-Q and completed private-trace cleanup. An AX `Disabled` flag is not evidence of a hung process: it is also present in earlier successful window hierarchies.

The exact supported boundary is **after trace startup, before observed inventory/table view attachment and XCTest window discovery**. The old evidence has no independent `NSApplication.windows` snapshot, AppModel completion marker or scene lifecycle marker. It cannot prove that no native window of any kind was allocated, nor identify an internal SwiftUI/AppKit failure.

## Comparison with earlier window-opening runs

| Evidence | 40309598774 | 40316125739 | 40322862024 |
|---|---|---|---|
| Candidate | `a5a66ef` | `3c99886` | `343ac0f` |
| Runtime | macOS 26.6.2 / 25G83, Xcode 26.5 / 17F42 | Same | Same |
| Cases preceding the execution-level test | Header sorts, draft cancellation, columns, layouts | Same four | None |
| Table observer after trace start | 0.438 s | 0.359 s | Absent |
| Native inventory-window attachment after trace start | 0.723 s | 0.560 s | Absent |
| Execution-level test's window | Visible inventory, AX main window, native attachment | Same | No visible or AX window |
| First case of the entire job | Header test also opens a window on its first launch | Same | Execution-level case fails to open one |

Earlier recordings and AX hierarchies show the real eight-item synthetic inventory and native table. Both earlier execution-level launches used the same QA trace arguments and immediate activation, then reached the old selection failure. The first header test also opened a window on a fresh job, without selection diagnostics. This rejects “the runner can never create a first window” and prevents treating a warm-up predecessor as a fix.

The unchanged `DebuggerLLDB.DebuggerVersionStore.StoreError` warning occurs in both successful-window and missing-window launches; it does not establish a cause.

## Lifecycle and hypothesis audit

| Hypothesis | Evidence and remaining limit |
|---|---|
| Process did not launch / crashed immediately | Rejected: app PID, automation setup, menu bar, trace writes and normal Quit are present. |
| App is running without a native window | Consistent; not confirmed because the previous trace only observed the table-owned window, not all NSApplication windows. |
| Hidden, minimized, non-key or offscreen native window | Not excluded. No visible/AX window or inventory observer exists, but no all-window native snapshot was retained. |
| Window exists but XCTest's locator misses it | Unsupported so far: recordings and absent view observer independently agree with XCTest. A blank/unattached native window is still possible. Do not change the locator without native evidence. |
| Blocked before scene/view attachment | Strongly consistent. AppModel completion, scene body and InventoryView construction were not instrumented, so the earlier blocking point remains unknown. Successful idle waits and Quit argue against a permanently wedged event loop. |
| Restoration/shared preferences | Plausible but unproven. Fixture mode isolates application configuration/data, not every SwiftUI/AppKit persisted window/sidebar/table setting. The earlier test was fifth; the isolated one was first. No previous restoration/default-launch metadata was retained. |
| Immediate extra activation | Not a sufficient cause: the identical launch-helper call worked in earlier first launches and the traced fifth launch. A timing/state-dependent interaction remains possible; compare one launch without it. |
| Selection diagnostics affect cold startup | Not excluded: the same instrumentation worked on earlier later launches, but there is no earlier matching cold, traced isolated run. Compare a launch with selection diagnostics disabled while independent startup observation stays enabled. |
| InventoryWindowLayout removes/hides the window | No supporting evidence. It operates only after native attachment, schedules frame fitting and changes a frame only when needed. It never opens, closes, orders out or activates a window. New observations bracket its existing work. |

`MacventoryApp` declares the real inventory `WindowGroup` first, followed by Settings. It has no custom launch/restoration override. Its model is a StateObject; previous logging began inside the model, not at successful scene/view completion. AppModel's synthetic branch initializes services and fixture records, then schedules leftover-record loading. The delegate only schedules official-icon assignment. InventoryView's selection observer requires inventory-content construction, so its absence cannot locate a failure earlier in initialization.

Apple documents that [default scene launch behavior](https://developer.apple.com/documentation/SwiftUI/Scene/defaultLaunchBehavior(_:)) and [restoration behavior](https://developer.apple.com/documentation/swiftui/scene/restorationbehavior(_:)) are separate. This patch changes neither. It observes the documented AppKit default-launch flag; a false flag has several possible meanings and is not, alone, proof of restoration. The [window update notification](https://developer.apple.com/documentation/appkit/nsapplication/didupdatenotification) provides an event-driven observation point without calling `updateWindows()`.

## Regression attribution

Commit `343ac0f` did not change WindowGroup, AppModel initialization, the delegate, InventoryWindowLayout, launch-time activation/window waiting or the selection-instrumentation implementation. Its application changes were two Name-cell accessibility identifiers; its test/CI changes made the execution-level test the first case in an isolated dispatch. These facts narrow the difference but do not prove or disprove a compiled-code regression. There is no matched isolated pre-commit run. **A startup regression caused by that commit is not established, and its selection correction was not exercised.**

## Minimal next experiment, not a production fix

The local patch adds independent `startup-lifecycle.jsonl` observation only when isolated mode, `--ui-testing`, `--qa-startup-diagnostics` and a valid fresh trace nonce are present. The new observer's nonce is passed in the explicit `MACVENTORY_QA_STARTUP_TRACE_ID` launch environment entry, not as another positional argument. This avoids introducing a new argument-domain difference into all comparisons; it does not establish that the original selection nonce causes the failure. Existing selection trace arguments are preserved in arms A/B. It records app/model initialization milestones, scene evaluation, InventoryView initialization/body/appearance, existing layout-reader attachment and before/after frame fitting. Notification snapshots include NSApplication running/active/hidden/policy state and all native windows with number, content view, frame, visibility, key/main, minimized/restorable/occlusion state. No `NSApplication.shared` access instantiates an app early. Window updates are deduplicated, event-driven and bounded to 256 KiB. There is no timer, sleep, event monitor, preference write, responder override, window constructor/order/activation call or selection setter in this observer.

The XCTest controller separately retains NSRunningApplication process state, PID-filtered window-server metadata, actual XCTest window count/state, AX hierarchy and a screen attachment after the original window wait and before teardown. Window-server data can be permission-limited and is secondary to the app's own NSWindow list. Both processes use monotonic uptime for correlation. Existing selection traces remain attached for the two arms that enable them. All evidence is captured before normal Quit and app-owned private-directory cleanup.

Proposed next hosted input: **`selection_scenario=startup`**. A matrix selects one method from `MacventoryStartupDiagnostics` as the first and only GUI test in each of three independent `macos-26` jobs:

1. `testAOriginalActivationAndSelectionDiagnostics`: original immediate activation and selection diagnostics.
2. `testBLaunchWithoutExtraActivation`: same fixture/diagnostics, omit only the extra launch-time activation.
3. `testCOriginalActivationWithoutSelectionDiagnostics`: original activation, selection diagnostics disabled; independent startup observation remains.

Each is one planned launch, with the existing 10-second window bound, real sidebar validation and real inventory-table attachment. A precondition refuses to start if a Macventory process already exists; it does not terminate that process. No selection, management operation, artificial window, New Window command, retry, recovery or extended timeout is introduced. A failed arm stays failed; `fail-fast: false` lets the independently planned comparisons finish. Startup-only success cannot satisfy `isolated` or `full` coverage. CI preserves Xcode's actual result, requires the exact one case selected by that arm and rejects a sequential startup suite or an unexpected XCTest predecessor. It exports summary, test tree, that arm's activities and all attachments even after a finalized failure. Each job uploads a distinct `verification-ui-startup-<arm>` artifact; recorded arm, candidate SHA and scenario must agree. An explicit allowlist retains runner name/image version/run identity for environment comparison without dumping secrets.

[GitHub provisions a fresh VM per hosted job](https://docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners/use-github-hosted-runners). The three comparisons therefore do not inherit each other's restoration state, preferences or previous Macventory process. No application cache is restored between them. Each trace still records known restoration preferences, persistent preference key names, `NSOpen` presence (without file paths), and whether that app's saved-state directory exists. Runner-image differences and observer timing effects must still be considered; an alternate arm succeeding is not by itself a production repair. The baseline lifecycle and native snapshots distinguish no-window/hidden-window/AX-only failure directly. The two variants test activation/selection-probe hypotheses. If only the no-selection-diagnostics arm works, distinguish the selection observer itself from its existing argument transport before attributing the cause. A matched pre-commit comparison remains available if the evidence requires it.

Interpret the evidence as follows:

- Model begin without model end: localize between recorded services/fixtures markers; do not assume a scene failure.
- Model complete and scene evaluated, no InventoryView initialization/native windows: investigate scene presentation/restoration.
- Native windows present but hidden/non-key/minimized/offscreen: inspect native state and layout records before changing launch behavior.
- Visible inventory native window/view attachment, zero XCTest windows: an XCTest/AX discovery issue becomes supported; only then evaluate a locator correction.
- Window discovery but no real inventory table: report view attachment as the failed stage.

No production startup correction is justified yet. The recommended change is this diagnostic checkpoint. If lifecycle/restoration is then established, isolate startup using supported scene/restoration policy only in synthetic QA, while continuing to require the genuine inventory window.

## Repair and verification sequence

The root-cause implementation task remains active; this document is not its completion claim. Hosted evidence is required to select the actual repair. The installed macOS 26.5 SDK declares both `Scene.restorationBehavior` and `Scene.defaultLaunchBehavior` available from **macOS 15.0**. If presentation/restoration is demonstrated responsible, a supported synthetic-QA policy must have an explicit availability guard and retain the existing macOS 13 and normal-production behavior. No such speculative policy is installed by this patch.

1. **Gate A:** obtain one approved startup dispatch on the reviewed commit. Inspect the original cold-start arm and compare the independent variants. Fix the demonstrated initialization/presentation/window/discovery layer locally, then seek approval for focused verification of the correction. A diagnostic or alternate-arm pass alone is insufficient.
2. **Gate B:** after genuine window/table startup succeeds, run both `isolated` selection cases on the intended candidate SHA. Require the intended native row hit, persistent native selection, exact binding/observed installation ID, Details identity and all original Management assertions. If selection still disappears, repair the layer demonstrated by the native/AppKit/SwiftUI evidence; no extra click, injected binding, keyboard fallback or relaxed condition is allowed.
3. **Gate C:** after the focused gate passes, verify all 17 primary cases, builds/units, packaging/checksums and independent diagnostics on the exact same final candidate SHA. Any subsequent code change invalidates final-SHA evidence. Do not repeat the full suite without a meaningful change or enter it while startup/selection is unverified.

The next approval request covers one commit/push to stabilization and one startup workflow dispatch only. It does not authorize another candidate commit, selection/full dispatch, merge, tag, release, Homebrew change or real software operation.

## Local validation

- Final local application build passes. The existing native SwiftPM build-system deprecation warning remains; the new diagnostic introduces no compiler warnings.
- The complete lifecycle/handoff/selection-observer source and the controller's native-process/window payload pass Swift 6 type checking with warnings treated as errors. UI test source parses. Full UI XCTest type checking/execution is unavailable locally because this machine has Command Line Tools, not full Xcode; parsing does not replace hosted compilation.
- Existing fixture-only Swift suite: 225 registered tests in 24 suites, 222 passed and three intentional opt-in live integration skips; no failures. `MACVENTORY_LIVE_TESTS=0`. The restricted initial build could not start SwiftPM's sandbox; the subsequent approved local build retained that sandbox and passed.
- All 16 Python CI-reporting regression tests pass. Added checks require one explicit case per fresh-runner arm, reject implicit sequential suites and XCTest predecessors, reject using startup as selection/full coverage, verify method-only execution and actual Xcode failure propagation, reject mismatched arm metadata, and prove that a failed activity export still attempts attachments while failing that arm. Matrix checks require all three arms, no shared cache, disabled fail-fast and distinct artifact names.
- Workflow YAML, all 16 inline shell fragments, the wrapper's shell syntax and Git whitespace checks pass. Publication preflight: 151 inputs, zero findings.
- All 17 primary class methods and helpers are byte-identical to HEAD. The common launch helper retains original defaults and window timeout; its optional changes are used only by the new diagnostic class. The existing selection-observer implementation is byte-identical to HEAD; only its shared private-file allowlist/cleanup recognizes the additional lifecycle file.

**Ready for review and one controlled hosted `startup` diagnostic, not a verified startup correction.** Separate approval is required for commit, push and dispatch. HEAD remains `343ac0f`, local main remains `a5a66ef`, and the original documentation commit remains its preserved parent. No full 17-test GUI suite, new hosted run, commit, push, PR or merge was performed. No real installed application/package, user preference, user process or privileged helper was modified by these local checks.
