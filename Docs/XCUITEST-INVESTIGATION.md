# PR #1 XCUITest execution investigation — 24 October 2026

**Historical report.** v1.1.0 was released on 27 October 2026 with passing native/GUI CI. See [current verification](VERIFICATION.md) for completed checks and manual VM testing. Failed/pending checks, branch state and proposed next steps below apply only to the dated development pass.

Version 1.0.0/build102 and pinned Xcode 26.5 are unchanged. Corrections are local and uncommitted. No corrected cloud run has executed.

## Evidence reviewed

[Run 40028914665](https://github.com/vadimtanel/MacVentory/actions/runs/40028914665), revision e5db815df3eae0545d22eec7d0568d8b97453c14:

- Native job 120671970358 passed every step: SwiftPM build/tests, Xcode application build, all test-target compilation, Xcode unit tests, packaging and artifact validation.
- GUI job 120673497140 compiled and executed 10 tests, with 11 failure records across 8 tests; column visibility and refresh/cancel/filters passed. These are runtime assertion/query failures, not compiler failures.
- Full GUI job log and verification-ui artifact 12533388854 were inspected. The artifact ZIP SHA-256 matches 77fbe6ed4fca6a8bb1d51b2c49e614a5b3c490b2f612e350a0381114118deda9.
- Existing zstd decoded the xcresult's compressed data records without Xcode. All eight text accessibility hierarchy attachments were read, together with relevant activity/test-summary records and screen-recording frames. The unmodified result bundle, decoded evidence and extracted frames remain in ignored build/ui-investigation. No local xcresulttool/Xcode installation was required or attempted.

## Findings

| Failure | Evidence | Classification and correction |
| --- | --- | --- |
| Native header sorting, selection/details, row-primary-action and uninstall simulation cannot find Example App | Hierarchies for PIDs 2211, 2781, 4513 and 4808 contain Outline identifier inventory.table and the Example App static text. There is no AXTable matching app.tables. The sidebar is also an Outline, with a different identifier. | Incorrect accessibility-role assumption. Resolve inventory.table by identifier and assert its role is outline or table. Keep all row/header/action assertions. |
| Search restoration at original line 29 | Empty-state assertion and typing/clearing complete; PID 3019 hierarchy shows a cleared search field and Example App inside inventory.table (Outline). | Same incorrect table query, not a demonstrated search bug. Correct the table query and explicitly assert the search value is empty before checking the restored row. |
| Keyboard test at original line 46 | Refresh/cancel/refresh assertions pass. PID 2584 hierarchy exposes Show system applications as CheckBox value 0 in the settings sheet. | Incorrect control role, not a keyboard-refresh failure. Query checkBoxes, retaining the existence assertion and appearance-picker check. Correct the same toggle query in the protected-preview test. |
| Cancel retains 28 instead of 30 | Cancel center is (792,734); click log says Falling back to element center point. The 1024x768 screen recording shows the Dock over the settings footer with System Settings under the cursor. Following log records System Settings as an interruption. The sheet remains open; the edit is still the same draft. | Genuine compact-display presentation bug, exposed by the hosted display, combined with a missing test transition assertion. Fixed 680-point content exceeds the usable sheet area. Cap presentation height using NSScreen.visibleFrame, retain the existing scrolling content/minimum, and reserve sheet/chrome headroom. Require the actual settings button to be hittable and the sheet to disappear before reopening. |
| About links at original lines 150–152 | PID 3642 snapshot still contains the settings sheet/Discovery value28 and no About window. Video shows System Settings in front after the failed footer clicks. | Downstream failure of settings dismissal. The test never established an open About window, so this run does not show a broken Link or wrong Link role. Require sheet dismissal and About Macventory window existence, then retain all three Link-role/label assertions scoped to that window. No speculative production Link changes. |
| Column visibility passed despite table queries | The old assertion only checked that app.tables.firstMatch.buttons[Version] did not exist. With no Table ancestor, that absence was vacuous. | Strengthen coverage: prove Version header exists in the identified inventory before hiding it, verify absence there, then verify restoration after Reset Columns. |

No cross-test settings persistence is demonstrated: launch logs show a distinct terminated/relaunched process per test; isolated fixture configuration starts from ScanConfiguration and does not write real preferences. The Cancel failure happens within one undismissed sheet. The cancellation test now explicitly checks initial30, edited28, switches to another page, requires dismissal, reopens and still requires30. The Done test still requires28 after a verified close/reopen. Neither expected value is relaxed.

System Settings is an observed hosted-desktop interruption caused by clicks landing on the Dock. It is not evidence of an Apple Account, signing or general XCUITest-permission blocker. No workaround dismisses system permission prompts, changes the runner image, hides the Dock, skips tests or masks failures.

## Minimal implementation scope

- Sources/Macventory/SettingsView.swift: shared display-aware presentation height; stable identifiers on Cancel/Done. Transaction/commit/cancel logic is unchanged.
- Sources/Macventory/InventoryView.swift and Sources/Macventory/MacventoryApp.swift: use that height for the sheet and standalone Settings scene.
- UITests/MacventoryUITests.swift: identifier-based inventory query, correct checkbox queries, sheet dismissal/hittability and About-window preconditions, stronger column/search/cancel assertions.
- This report, plus links/current status in VERIFICATION.md and CHECKPOINT.md.

All ten test methods and their original behavior checks remain. Assertion sites increase from55 to69. No removal, ownership, confirmation or executor code is changed. Tests still launch exclusively with --ui-testing and use simulated removal. Real application/package/Trash operations, real preferences and real cache maintenance are not exercised.

## Verification and remaining work

Local SwiftPM build passed (2.72 seconds). Swift Testing reports91 tests/12 suites passed, with the three opt-in live integration tests skipped. Swift parser validation of the XCUITest source and Git whitespace checks pass. Static checks verify all ten methods remain, explicit modifierFlags on every typeKey call, no skips, and unchanged production safety code/workflows/version/build.

These checks do not compile XCTest UI APIs or execute corrected macOS26 UI interactions. Hosted Xcode build/test and full GUI execution must rerun after explicit approval to commit/push the existing fix/cloud-xcode-ci branch. About Link-role compatibility after successful window presentation remains to be observed; the recorded failure never reached that state. Display fitting is an evidence-based correction, not a claimed passing cloud GUI result. No commits, pushes or merges were performed during this investigation.
