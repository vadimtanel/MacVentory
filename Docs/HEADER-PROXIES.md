# Header proxy investigation — d93cf87, 24 October 2026

## Confirmed new finding

[PR run40041664648](https://github.com/vadimtanel/MacVentory/actions/runs/40041664648), macOS26.6.2/Xcode26.5/SDK26.5/Swift6.3.2, passes the native pipeline and9/10 GUI methods. The sorting method records one failed hittability precondition; the helper now correctly stops without a second click. This is not a passing GUI suite.

Artifact12539643642 was downloaded and its SHA-256 matches c4c799028e42ad5eb9ce7037b94d36c86c302138566be270bf15812b29e16bc1. The full job120715143852 log, all four retained phase accessibility trees and the screen recording were inspected. Local evidence remains ignored under build/header-proxies.

| Header | Frame before selection | Hittable in all four phases |
| --- | --- | --- |
| Name |263,158,189,28| false |
| Version |452,158,92,28| true |
| Source |544,158,137,28| false |
| Size |681,158,102,28| false |
| Installed |783,158,117,28| false |
| Last Opened |900,158,114,28| false |

All exist. The phases are before selection, after selection/Details, Version ascending, Version descending. The states do not change. Therefore neither Details insertion nor Version sorting introduces this defect. Earlier suggestions about that sequence causing it are superseded.

The tree places all six under the same header Group at253,158,771,28, inside inventory.table Outline at252,157,773,501 and ScrollView at253,158,771,499. Every header is contained within that viewport and group. Main window is1024x646 at0,45. Recordings show ordinary visible headers, no covering sheet, menu or visible overlay; the initial cursor is near the menu bar, not hovering Version. Generic window sizing, off-screen Source, Details overlap and a Version-only regression do not explain these observations.

## Root-cause boundary

Confirmed failure class: a pre-existing native-header hit-testing disagreement affects five of six exposed header buttons on this runner. The defect is not specific to Source's comparator or caused by opening Details. XCTest's isHittable calculation returns the recorded pattern before any sorting interaction.

The attachments expose buttons/geometry but not native AXActionNames, activation points, AppKit hit-test return objects, or native Source action results. They cannot prove whether the affected bridge supplies an invalid hit region/proxy or XCTest interprets valid native information incorrectly. Existence, visible bounds and AXPress availability are different properties. Native semantic action success also cannot prove mouse clickability. The precise framework-vs-XCTest cause remains unconfirmed; no production workaround is justified yet.

## Comparison prepared for the affected hosted runtime

Diagnostics/HeaderProxyProbe.swift is a standalone diagnostic executable, not an application target or replacement test. scripts/probe-header-proxies.sh compiles it with the real app sources excluding the app entry point, linking the existing Xcode-built MacventoryCore.framework. It requires --ui-testing and a named comparison case. It runs only fictional data/isolated InventoryView; it does not load real settings/cache, inspect installed software, or invoke any removal operation.

Four separate bounded processes compare:

1. Plain SwiftUI Table with standard KeyPathComparator sorting.
2. Custom comparator with the same single-active-sort binding behavior.
3. Column customization/customization IDs plus identifier/hint, empty overlay and context/primary-action modifiers.
4. Actual InventoryView/AppModel in fixture mode, including normal wrappers/sidebar/Details.

Each records before selection, after selection, Version ascending/descending and native Source ascending/descending. For all six headers it logs AX actions/enabled state, position/size, exposed activation point if available, native accessibility hit-test object/title, native NSView hit-test class, header clipping, scroll frame, proxy/parent information and AX sort direction. It uses native header AXPress for semantic diagnosis and checks actual Source direction and selected row after those actions. It never sends coordinate clicks. Header centers are used only as read-only hit-test inputs.

AppKit's generated NSAccessibilityTableHeaderCellProxy exposes its legacy public accessibility API. The diagnostic uses that deprecated API because the proxy need not conform to the modern NSAccessibilityProtocol. Deprecation warnings are retained in compile.log. Unsupported optional activation points are recorded as not exposed rather than invented. No private API, swizzling or proxy replacement is used.

A single new CI step runs this comparison after the existing XCUITest step, including when that test fails. The Xcode26.5 pin, native pipeline and all10 GUI methods/behavior assertions are untouched. Existing failed-GUI reporting still fails the job; diagnostic results cannot override it. The four cases each have a45-second timeout; errors/nonzero statuses are reported and fail the diagnostic step after collecting other cases. Logs live in build/verification/header-proxies and are included in the existing verification-ui upload.

## Local verification

Using existing Swift6.4/SDK26.5 on macOS27.0.1, all four native comparisons completed. In all cases all six proxies expose AXPress; AXActivationPoint is not exposed. Native window accessibilityHitTest returns the corresponding Source proxy across all phases. Native Source actions yield AXAscendingSortDirection then AXDescendingSortDirection and preserve the selected example row as its row index changes with ordering. Custom comparator/configuration is not demonstrated defective locally.

The probe compiles with the actual app source, and local SwiftPM build/fixture tests pass. Swift Testing reports91 tests/12 suites passed; three opt-in live integrations skipped. Swift source parsing, shell syntax, YAML parsing and whitespace checks pass. The hosted framework-linking path is prepared but cannot be executed locally without Xcode; local probe compilation links existing SwiftPM core objects instead. Actual hosted probe results remain pending.

These are native semantic checks on macOS27, not XCTest results or proof of mouse interaction on macOS26.6.2. No actual physical-user defect or XCTest-only limitation is claimed proven.

## What a new approved run must resolve

Compare action availability/native hit results on the same macOS26 runner with the already-measured XCTest states. If plain/customized tables differ, isolate the relevant configuration. If the minimal case and real inventory share invalid native hit results, investigate the native framework bridge. If native hit results/action availability are sound while XCTest rejects headers, further validate the cross-process AX path before calling it exclusively an XCTest calculation limitation.

A supported complementary method is native semantic AXPress plus real direction/order/selected-identity verification. It tests accessibility activation and sort behavior; it does not verify mouse hit testing or drag/reorder gestures and cannot replace this test merely to obtain green CI. No XCUITest strategy was changed. Changing that strategy requires affected-runtime evidence and an explicit explanation of the remaining interaction coverage.

The next step requires approval to commit/push this diagnostic candidate. No new hosted run has executed, no production fix is claimed, and no commit/push/merge/tag/publication or real removal/cleanup occurred.
