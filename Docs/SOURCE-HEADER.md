# Persistent Source header investigation — 24 October 2026

**Historical report.** v1.1.0 was released on 27 October 2026 with passing native/GUI CI. See [current verification](VERIFICATION.md) for completed checks and manual VM testing. Failed/pending checks, branch state and proposed next steps below apply only to the dated development pass.

**Superseded evidence:** [the d93cf87 diagnostic run](HEADER-PROXIES.md) confirms five of six headers are not hittable before selection, unchanged after Details/Version sorts. Those actions do not cause the failure. The historical investigation below describes earlier evidence only.

Baseline271cd134bd22bc56c3f8f89d8635d5c25d44cc4b, branch fix/cloud-xcode-ci. This is a diagnostic/test correction candidate, not a claimed production fix or passing GUI run. Version1.0.0/build102, pinned Xcode26.5 and responsive layout remain unchanged. No commit/push/merge/tag/publication was performed.

## Latest evidence from both runs

| Run | Native | GUI |
| --- | --- | --- |
| [PR40039301815](https://github.com/vadimtanel/MacVentory/actions/runs/40039301815) | Every build/test/package/validation step passed | 10 tests executed, 9 pass; sorting test fails |
| [Push40039297430](https://github.com/vadimtanel/MacVentory/actions/runs/40039297430) | Every build/test/package/validation step passed | Same failing test and sequence |

Full job logs120707567201/120707413911 and verification-ui artifacts12538991012/12538907008 were retrieved. ZIP SHA-256 values match GitHub: PR16b1efca9a515949def2bd5bd37b2fe5edc2a6caa3a0d644474334eae1c194f2; pushccefa79d0846d1fef63dd63a37f44f145e0fc5d9cc55045448a9df5a7520735c. Intact bundles, decoded records and frames remain ignored under build/source-header.

The actual runner is arm64/macOS26.6.2 build25G83, Xcode26.5/17F42, Swift6.3.2, SDK26.5. Xcode/SDK26.5 must not be confused with the host OS release.

Both tests select Example App, find Details, successfully click Version twice, then find Source at{{544,158},{137,28}}. Its hittability predicate times out. The helper then incorrectly continues into click, producing a second failure record for the same test. XCTest retries automatic scrolling withdx26/dy105 without making Source hittable. Thus the logs say2 failure records but only1 of10 test methods fails.

Recorded1024x768 video shows Source fully visible in the inventory header above the rows, separated from the bottom Details pane. Settings, Columns, main window and details actions fit. No popover, menu, sheet, tooltip or obvious visual overlay covers Source. The old generic window-overflow explanation is insufficient; no new window-sizing changes are made.

The current xcresult saves a1096-byte NSKeyedArchiver snapshot of the Source Button, with title Source, empty identifier/label, no children, its frame and a parent accessibility token. It does not include a complete ancestor tree, scroll clipping rectangles or native hit-test return value. Activity logs request cached hierarchies but do not supply the missing pre-selection/pre-sort phase snapshots as retained full trees. The parent token alone cannot prove an intercepting ancestor. We inspected the actual saved records, rather than treating a request-for-snapshot log line as evidence that a full attachment exists.

## What is and is not confirmed

Confirmed: the control exists, is visibly on-screen, and is rejected by XCTest hit testing after two Version clicks. There is no evidence of Source being off-screen, a missing comparator, or a broken compact window at this revision. The test never activates Source, so that run cannot prove its comparator or selected identity after activation. It also never measures Source hittability before selection or immediately after opening Details.

Not yet confirmed: whether macOS26.6.2's SwiftUI/AppKit AXOutline header bridge itself has a hit-test defect, whether XCTest misinterprets the native proxy, or whether a nonvisual ancestor/hit region in that runtime intercepts the header. The retrieved evidence cannot honestly distinguish these. A speculative Table rebuild, custom header, substitute sort control or new layout workaround would not be justified.

## Local native probe

A separate two-row SwiftUI Table probe and a harness using the actual InventoryView/AppModel were compiled with existing CLT Swift6.4/SDK26.5 and run on local macOS27. The latter was launched with --ui-testing and did not load real settings/cache, scan real installations, or call any removal operation. It hosted its own window instead of selecting an existing Macventory instance.

The actual InventoryView probe checks native window accessibilityHitTest at each native header rectangle, selects a synthetic row, allows a render pass to open Details, performs the native Version header accessibility action twice, then the native Source header action twice. These are native semantic AX actions for diagnosis, not screen-coordinate clicks or a replacement for the existing XCUITest clicks. AppKit exposes its generated NSAccessibilityTableHeaderCellProxy through the legacy AX API; that API is used only in the ignored diagnostic harness.

Source hit testing returns the Source proxy before selection, after selection/Details, after Version ascending and after Version descending. Subsequent native Source activation reports AXAscendingSortDirection and AXDescendingSortDirection. Native table selection remains present. Native header rectangles/parent proxy identities and all phase results are logged under build/source-header/probe. No header-view interception is observed locally. This demonstrates working local native paths; it is not an XCTest pass and does not establish behavior on macOS26.6.2.

## Minimal supported changes

Only test code and reports change; no production window/Table/column/safety code is altered without evidence.

- clickVisible now throws through XCTUnwrap on failed existence or hittability. XCTUnwrap records a failing assertion, then terminates the caller's test through an uncaught test error. It cannot fall through to click, another header, or the next sort direction. Tests that use it propagate throws. No failure is suppressed or converted to a skip.
- The same sorting test captures all six header frames/existence/hittability/values plus full application accessibility ancestors and a screen attachment before selection, after Details opens, and after each successful sort direction. Attachments are retained even on successful phases, filling the specific evidence gap in the latest bundles.
- All six native headers and both clicks per header remain in the same order. Existing selection checks remain; actual org.example.app details identity is additionally asserted. For Version and Source, native first-row content must show the expected ascending/descending fixture order after activation. No alternate sorting mechanism is invoked by the UI test.
- The existing core regression additionally checks reverse Source ordering and normalization to ascending Source when switching from descending Version.

All10 UI methods and their behavior coverage remain. The current hosted Source failure may still occur; this candidate deliberately preserves that failure until it is diagnosed/fixed on the affected runtime.

## Local checks and required next run

SwiftPM build passes. Swift Testing reports91 tests in12 suites passed, including the strengthened comparator regression; three opt-in live integrations are skipped. UI Swift syntax parsing and Git whitespace checks pass. These checks do not compile or execute the revised XCUITest against Xcode26.5.

After explicit approval to commit/push this reviewable candidate, inspect both new run results. Compare Source hittability and native ancestry at before-selection, after-Details, Version ascending and Version descending. Determine the first phase that fails; verify its frame against actual ancestor clips and overlays. If Source can be activated, require actual row-order reversal and preserved org.example.app identity. If it still fails, use the newly retained full hierarchy to separate a proxy/hit-region defect from XCTest-only behavior before making a production workaround. A full9/10 result is still a failing GUI suite; success requires a fresh hosted10/10 run.

No local Xcode installation/Apple authentication; no real uninstall/Trash/package cleanup/user-data deletion; no production removal code changes or weakened safety assertions.
