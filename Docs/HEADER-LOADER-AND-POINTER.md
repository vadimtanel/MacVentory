# Header loader correction and pointer diagnostic — 24 October 2026

**Historical report.** v1.1.0 was released on 27 October 2026 with passing native/GUI CI. See [current verification](VERIFICATION.md) for completed checks and manual VM testing. Failed/pending checks, branch state and proposed next steps below apply only to the dated development pass.

Base revision: `4f3f34a51d935b2175d9a3c2d85bfa269226e7e4`. Changes are local and uncommitted. No corrected hosted run has executed. No production source, packaging, version/build, Xcode pin, uninstall safety or original GUI assertions changed.

## Confirmed loader cause and exact correction

The user inspected verification-ui from [PR run 40043829456](https://github.com/vadimtanel/MacVentory/actions/runs/40043829456) and [push run 40043826648](https://github.com/vadimtanel/MacVentory/actions/runs/40043826648): all four native probes aborted with status -6 before executing their cases, because `/Library/Frameworks/MacventoryCore.framework/Versions/A/MacventoryCore` was missing. Those failures provide no native comparison result. These two artifacts were not independently downloaded in this session; web retrieval of their run pages failed.

The launcher previously supplied LC_RPATH but linked an absolute framework install name. Rpaths resolve `@rpath` dependencies; they do not redirect that absolute name. The revised `scripts/probe-header-proxies.sh`:

- Resolves the supplied Debug products directory to an absolute path and requires `MacventoryCore.framework/Versions/A/MacventoryCore` to exist before compiling.
- Records `otool -L` output in `linked-libraries.log` and the SDK/compiler/OS/Xcode information in `toolchain.log`.
- Passes `DYLD_FRAMEWORK_PATH=<Debug products directory>` in the environment of **each** of the four subprocesses. The environment change is confined to those diagnostics.
- Requires each process to exit successfully, emit its case/OS startup marker, reach all six phases and emit 36 JSON header measurements. A loader abort or incomplete diagnostic fails the step; it cannot become a successful native comparison.
- Honors an explicit SDKROOT for local CLT verification; hosted CI continues to use the SDK from pinned Xcode 26.5. Uses a project-local module cache.

No framework is installed into `/Library/Frameworks`. Neither the framework nor production executable is rewritten. Existing ad-hoc signing of the standalone probe remains. An install-name rewrite was unnecessary in the local reproduction.

## Controlled local reproduction and native results

Environment: macOS **27.0.1 (26A434)**, arm64; Command Line Tools Swift **6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)**; compilation SDK **26.5**. Full Xcode is absent. This is not the affected hosted macOS 26/Xcode 26.5 environment.

To test the actual loader failure, core sources were compiled into an isolated framework under ignored `build/loader-check/Debug`, with precisely the absolute install name shown above. This is a locally constructed framework, not an Xcode-built Debug product. The revised launcher compiled and signed its probe against it. `otool -L` confirms the absolute dependency remains unchanged.

Control: launching the same executable without DYLD_FRAMEWORK_PATH returns **-6**, with the same missing `/Library/Frameworks/.../MacventoryCore` dyld message. With the variable set, all four processes reach main and complete all six phases, each returning **0**. Final measurements below were collected with desktop access. An earlier restricted-desktop attempt produced invalid window geometry and an InventoryView assertion failure; it is not used as native desktop evidence.

| Case | Measurements | Matching native AX hit targets | AXPress exposed | Source direction after actions | Selected row after Source asc/desc |
| --- | --- | --- | --- | --- | --- |
| Plain SwiftUI / keypath | 36 | 36/36 | 36/36 | Ascending / Descending | 0 / 1 |
| Custom comparator | 36 | 36/36 | 36/36 | Ascending / Descending | 0 / 1 |
| Column customized | 36 | 36/36 | 36/36 | Ascending / Descending | 0 / 1 |
| Actual InventoryView | 36 | 36/36 | 36/36 | Ascending / Descending | 0 / 1 |

All native AX hit results are `NSAccessibilityTableHeaderCellProxy` with the corresponding column title, across before-selection, after-selection, Version ascending/descending and Source ascending/descending. AppKit view hit tests return NSTableHeaderView throughout. AXActivationPoint is not exposed. AXSortDirection for Source is unknown until Source is activated, then `AXAscendingSortDirection` and `AXDescendingSortDirection`. Selection starts at -1, becomes 0, moves to 1 for Version ascending, back to 0 for Version descending, then 0/1 for Source. These are native semantic actions and selected-row measurements, not proof of physical mouse interaction or independently observed selected application identity.

Initial native AX header geometry, in the native coordinate convention reported by AX (do not compare directly with XCUI screen coordinates):

| Column | Plain/custom/customized: x,y,w,h | InventoryView: x,y,w,h |
| --- | --- | --- |
| Name | 10,692,250,28 | 255,639,192,28 |
| Version | 260,692,132,28 | 447,639,92,28 |
| Source | 392,692,197,28 | 539,639,140,28 |
| Size | 589,692,133,28 | 679,639,102,28 |
| Installed | 722,692,148,28 | 781,639,117,28 |
| Last Opened | 870,692,144,28 | 898,639,114,28 |

The three synthetic windows have native frame `{{0,100},{1024,652}}`; InventoryView has `{{0,76},{1024,704}}`. JSON records also include phase, window frame, selected row, header-local rect, visible rect and scroll frame so hosted comparisons can be made without losing coordinate context. Local evidence is retained under ignored `build/verification/header-proxies/`, including `without-framework-path.log` for the control.

No first failing table configuration is demonstrated locally. The supplied macOS 26 XCUI observation (only Version hittable) and these macOS 27 in-process native results cannot establish an XCTest-only defect: both the runtime and the interaction mechanism differ.

## Independent real-pointer test prepared, execution pending

`MacventoryHeaderPointerDiagnostics.testSourceHeaderRealPointerBothDirectionsPreservesIdentity` is a separate XCTest class in the existing UI target. The original `MacventoryUITests` class and all ten methods remain byte-for-byte unchanged.

The diagnostic launches only `--ui-testing`, selects Example App, checks its identifier in Details, and establishes the opposite source order using the known-hittable Version header. Before each Source interaction it resolves the actual header again, requires a nonempty frame inside the foreground application's window, inventory table and native scroll viewport, and validates that its derived click point remains inside the header. It records isHittable, geometry, header value, full accessibility tree, row order and screenshots before and after each interaction.

It uses Apple's supported [element-relative normalized coordinate](https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate%28withnormalizedoffset%3A%29) and [XCUICoordinate.click()](https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/click%28%29). There is no global fixed screen coordinate, AXPress substitution, or fallback in the original strict test.

Both clicks must visibly reverse the complete two-row order. Ascending Source must yield `[Example App, example-tool]`; descending must yield `[example-tool, Example App]`. The selected `org.example.app` identity and Copy Identifier action must remain present after both. Expected full fixture order is the direction assertion; XCTest has no dedicated AXSortDirection property. The header's exposed value is recorded, and the separate native probe checks AXSortDirection directly.

CI runs the original ten-method class explicitly and then runs this separate diagnostic even if the strict suite or native probe fails. It saves `HeaderPointerDiagnostic.xcresult` and `header-pointer-diagnostic.log`. Diagnostic success cannot override strict-test failure, and diagnostic failure is not suppressed. Local parsing passes, but the XCUITest APIs cannot be typechecked or executed here without full Xcode. No pointer result is claimed.

## Conditional minimal final solution

Keep the strict test unchanged until the affected runtime supplies native **and real-pointer** evidence. If both AXPress and pointer clicks succeed while isHittable stays false, classify the observation narrowly as an XCTest header-proxy hit-point calculation limitation on the exact recorded macOS/Xcode builds. In-process native AX success alone does not establish the same cross-process behavior.

After that evidence, the proposed smallest final change is a dedicated header interaction helper using validated element-relative XCUICoordinate clicks for **all six headers, both directions**, with explicit complete expected row order and preserved selected identity after every click. Keep ordinary controls' strict hittability checks. Record the discrepancy; do not conditionally catch a failure and retry through coordinates.

The current fixture cannot prove reverse ordering for every column: both Installed values are nil, and Size/Last Opened have only one known value with nils deliberately last in both directions. Before adopting that final test, supply deterministic, distinct nonnil metadata for both synthetic rows for every sortable field, with fixed dates and an explicit expected-order matrix independent of the comparator implementation. Establish an opposite order before each ascending check so every interaction must visibly change order. Preserve the original search/sorting and selection assertions. No such fixture or final interaction-policy change is made in this diagnostic candidate.

If real-pointer clicks fail, isolate the first failing one of the four native configurations on macOS 26 before changing production UI. If the plain table reproduces an actual native/pointer defect, extract ProbeTable's keypath case into an Apple Feedback reproducer, attach the native JSON/xcresult/recording, and quote the exact hosted OS build, Xcode build, SDK and compiler from the retained logs. The previously documented hosted environment is macOS 26.6.2 / Xcode 26.5 / SDK 26.5 / Swift 6.3.2; the corrected run must record and confirm its own exact builds. No affected-runtime minimal reproduction is claimed yet.

## Verification boundary

Locally proven: the exact loader error reproduces without the environment override; the override resolves that unchanged absolute install name; all four native cases complete with 144 measurements on macOS 27; shell syntax, Swift source parsing, workflow YAML and whitespace checks pass; the original ten-test class is unchanged.

Still required: pinned hosted Xcode compilation, all four native comparisons on macOS 26, separate real-pointer results, and ultimately a corrected hosted run passing **all ten original GUI tests**. This candidate is not a passing GUI fix. No commit, push, merge, tag, publication, local Xcode installation, Apple authentication, real removal or installed-application modification occurred.
