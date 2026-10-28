# Compact-display investigation — PR #1, 24 October 2026

**Historical report.** v1.1.0 was released on 27 October 2026 with passing native/GUI CI. See [current verification](VERIFICATION.md) for completed checks and manual VM testing. Failed/pending checks, branch state and proposed next steps below apply only to the dated development pass.

Baseline081166026965cdb975d2907ed142c0fae1e61f84, Macventory1.0.0/build102. Corrections are local/uncommitted. Xcode26.5 and workflows remain unchanged. Corrected hosted GUI execution is pending approval to commit/push.

## Both runs reviewed

| Run | Trigger | Native | GUI |
| --- | --- | --- | --- |
| [40031376348](https://github.com/vadimtanel/MacVentory/actions/runs/40031376348) | pull_request | All steps passed | 10 executed, 8 passed, 2 failed |
| [40031370109](https://github.com/vadimtanel/MacVentory/actions/runs/40031370109) | push, same SHA | All steps passed | 10 executed, 4 passed, 6 failed |

Full GUI job logs120681837047 and120681634407 and both verification-ui ZIPs were retrieved. Archive SHA-256 values match GitHub: PR414f4434e3887a1278019659327c73a139f8498e77127dfad1d3d83fbeec951d; push7f1b875ca4eda763b5f22ca6ecb92a4f7b515b1c98c7b0f122b859e14b88ccbf. Local evidence remains ignored under build/compact-investigation. Decoded xcresult text snapshots, activity records and available1024x768 screen recordings were inspected without installing Xcode. There are3 PR text hierarchies and15 push hierarchies; two PR recordings and six push recordings were extracted. Full xcresult bundles remain intact.

## Settings/Columns: confirmed geometric causes

PR accessibility snapshots show a main window at{{0,31},{1050,674}} but its NavigationSplitView at{{-143,31},{1337,674}}. Sidebar Settings is atx=-116; its entire74-point button is outside the window. The video shows clipped sidebar labels and details past the right display edge. This is content overflow inside the window, not merely an off-screen window origin.

Push snapshots additionally show the actual main window at{{-148,31},{1320,674}} on a1024x768 display. Settings is atx=-121 and Columns atx=1084. Both controls are physically outside the display. This explains the extra Settings/Columns failures; the counts must not be conflated with the PR run.

The root's minimum1050 exceeds the1024-point display, and default1320x820 is not display-aware. Selection then inserts a mandatory horizontal details pane into the detail region, combining table/content width,270-point details minimum and220/245-point sidebar. Native table columns contribute their minimum/intrinsic widths, and the parent split view can expand beyond its allocated window rather than provide a compact arrangement. Six column minima total640 before table insets; the former table minimum560 did not represent that content requirement. Different initial/restored frames account for the visibly different overflow geometries, but the evidence does not identify a particular saved-window preference as the cause. No real restoration preferences were cleared. Fixture column customization is already isolated; nothing in these failures demonstrates corrupted persisted customization or a changed column order.

## Source header: separate hit-testing failure

Both logs report Source at{{387,144},{137,28}}, which is on-screen. Version clicks work first, after selection has shown details. Source click retries invoke Scroll element to visible withdx6/dy249.5, then fail Not hittable. The PR video visibly shows Source alongside Version while the surrounding split view is clipped. This must not be described as Source being off-screen, a missing header, a comparator failure, or a confirmed settings/query-role issue.

The confirmed immediate failure is native accessibility hit testing rejecting an existing, visible header in the overflowing split/table hierarchy. Correcting that hierarchy removes the demonstrated layout defect; whether it fully resolves Source hit testing or exposes an independent AppKit/XCUITest issue requires a new macOS26 run. We cannot honestly identify a separate internal AppKit cause from these attachments. Tests retain native header clicks and now wait/assert that the actual header is hittable rather than relying on XCTest's failed automatic scroll attempts. No coordinate click, substitute sort control, skipped column or suppressed failure is used.

## Corrections

- Root minimum becomes900x520; desktop default remains1320x820 when it fits, capped to the current usable display on smaller screens.
- InventoryWindowLayout constrains initial/restored/moved/resized windows to their screen's visibleFrame, including changes of display or usable screen area. It does not read/write/delete saved window preferences. Windows already inside their usable display retain their frame.
- A GeometryReader allocates the actual detail region. At960 points or wider, native HSplitView keeps the side-by-side table/details layout (table minimum640, details270). Below that width, native VSplitView places details below the table. Sidebar, full-width table and Columns stay in the allocated width. Native table sorting/customization/context menu code remains unchanged.
- Compact Details keeps its actions in a bottom inset while metadata scrolls, with a native horizontal/vertical fitting action layout. The desktop Details layout stays unchanged. Selection, search, filters, settings/about and uninstall confirmation behavior remain intact.
- Stable Settings/About/Details-toggle identifiers are added. GUI tests query the real controls, require hit testing before clicks, and assert Settings/Columns fit inside the inventory window at launch. All ten methods and prior behavior assertions remain. No failure is ignored and no coordinate clicking is introduced.
- The generated Xcode project registers the new window-layout source. Project generator behavior and Xcode pin are unchanged.

## Local verification

SwiftPM build passes using existing Swift6.4/SDK26.5. Fixture tests report91 tests/12 suites passed; three opt-in live integrations skipped. UI Swift parser and project plist/whitespace/static coverage checks pass.

An isolated executable compiled the actual window-frame policy against AppKit/SwiftUI and tested: the observed1320-wide negatively positioned window on1024x768; the1050-wide PR window; an already-valid1320x848 desktop window on1800x1100 usable space; and an overflowing window on a secondary display with negative global coordinates. All four are contained after fitting, fitting is stable, and the valid large window is unchanged. This verifies geometry, not rendered SwiftUI hit testing.

A local --ui-testing process was launched, but computer-use inspection selected a separate existing Macventory instance. No UI actions were taken in that instance, no removal was requested, and that observation is not counted as a GUI pass. Only the isolated process launched for this attempt was stopped. Local compact/large rendered interactions have therefore not been verified; the available evidence is hosted recordings plus local geometry/build/tests.

## Required hosted verification

After approved commit/push, inspect both push and PR jobs separately. Require all ten GUI tests to pass, especially every native header in both directions after selection, Settings/Columns hit testing, compact details actions, filters/search and protected/simulated uninstall. Confirm the actual window/content/control bounds on the runner's display, successful sheet transitions and preserved selection. If Source remains visible but not hittable with contained layout, investigate it as a separate native accessibility issue with fresh attachments. Larger-screen manual/native UI verification also remains pending; geometry checks alone do not establish it.

No real uninstall, Trash, package cleanup or user-data deletion; no source/executor safety changes; no Apple authentication or Xcode installation; no commit/push/merge/tag/publication.
