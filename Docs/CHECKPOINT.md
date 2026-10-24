# Macventory 1.0.0 checkpoint — 24 October 2026

## Build107 — permission explanations, folder scope and sidebar selection

Final local artifacts VERIFIED: build107 app signature, ZIP integrity, DMG checksum, SHA-256 checksums and 106 exact source inputs/hashes pass. Publication review has zero findings. Complete safe suite rerun after the Settings shortcut fix: 148 tests / 19 suites pass. No owner-data change or Git index/history/publication mutation performed.

Added native Command-click multi-selection for inventory sidebar categories. Results use the union of selected library/smart/source categories; search and ordinary filters still apply, overlapping installations appear once, All Software resets the selection and Leftover Data remains a separate destination. User explicitly clarified inventory categories, not cleanup-group selection.

Permission diagnostics now distinguish target readability, parent-folder writability and Finder's Trash rejection, retaining operation/path and NSError domain/code when available. The former generic error did not establish which check failed. Read-only metadata showed the owner's Share container and parent owned by the current account with owner read/write; this does not establish the running app's TCC access. No live retry or privacy setting change was attempted. Guidance opens System Settings only on user action, disabled in QA; macOS grants cannot be bypassed by code.

Selected folders already submit their entire URL to native Trash, not their individual files. Added explicit whole-folder confirmation copy and visible personal-discovery on/off status with a direct Scanning Settings shortcut. Corrected that shortcut after native QA exposed a stale Boolean-sheet tab capture. Synthetic tests verify one whole folder target while retaining parent/unselected data.

148 safe tests / 19 suites passed. Native isolated GUI verified Command-click two-source union, search narrowing, separate cleanup navigation, detailed permission failure/help/OK, persistent error information, default-off status, Scanning shortcut opening the correct tab, opt-in personal suggestions and whole-folder review copy. No real user data, process, settings or permissions changed. Build107 packaging follows these final docs; preserve existing staged/unstaged work. No stage, commit, push, tag or publication authorized.

## Build106 — stale-target and optional personal-folder correction

Final artifacts VERIFIED: arm64/build106 app signature, ZIP integrity, DMG checksum, SHA-256 checksums and 104 exact source-archive inputs/hashes all pass. Publication review: zero findings. Documents/Downloads/Desktop opt-in remains off for the owner; only synthetic QA configuration was changed. No stage, commit, push, tag or publication performed.

Final safe regression result: 143 tests / 18 suites pass. Native GUI checks listed below passed. A final compiler/test-verified generic identifier-component prefix lead suggests personal folders even without a retained friendly name, while preserving explicit uncertainty and manual-only eligibility. Version 1.0.0/build106. Local packages and exact-manifest source/checksums are regenerated after final source/docs; review command results before release. Earlier test counts below are historical checkpoints. No commit, push, tag or publication authorized.

Preserved existing staged work. Root causes: cleanup validated all candidates before producing individual results, and partial refresh merged old groups without confirming continued existence. Added typed item outcomes and an injected cleanup runner: confirmed absence is No Longer Exists/Already Removed, not an attributed deletion; independent valid items continue after a denied/changed/missing item; duplicate/nested selections fail closed; unknown Finder outcomes stop later submissions and are never automatically retried. Cleanup results reconcile resolved candidates immediately, while refresh removes only confirmed missing observations and retains permission/inconclusive information. Combined management keeps preflight safety and reports missing cleanup items separately.

Settings → Scanning now has a default-off Documents/Downloads/Desktop related-folder option, backwards-compatible with saved configuration. Discovery checks direct children only (500/location, 30 matched measurements, five-second budget, 500 size entries/folder), uses known identity names/exact identifiers, and labels suggestions Possible Related Files — Manual Review Required. Ambiguous/shared/linked/unsafe candidates stay protected. No recursive personal-file sweep, elevation or privacy bypass. Turning it off removes personal suggestions immediately.

Native synthetic GUI passed Already Removed/OK/empty-group removal, mixed absent/simulated move/permission denial with corrected group totals, protected checkbox blocking, default-off setting, opt-in personal suggestions, Desktop permission details, individual selection/exact-path confirmation, Cancel and disabling discovery. Initial full safe suite passed 139 tests/18 suites; final follow-up tests/build pending at this checkpoint. No real user application/process/cache/preference/personal folder modified. No index operation, commit, push, tag or publication.

## Identity regression correction — current handoff

Final follow-up: 131 tests / 16 suites pass. Recorded extensions are excluded when their parent is installed/reinstalled or registered. Build105 artifacts are regenerated with this last safeguard; the prior 130-test count below is the earlier checkpoint.

Root causes: removal of the old product-specific hint exposed lack of a persistent identity index; retrospective discovery defaulted to raw identifiers; presentation then replaced these with repeated Unknown application labels. The earlier grouping also merged equal display names without parent evidence. Added ApplicationIdentityIndex.swift with bounded Codable storage, two-year retention, snapshot migration, bundle and embedded extension observations, conflict handling and naming provenance. Names resolve after filesystem candidate discovery, so ownership classifications and targets are unchanged. Parent relationships alone group components; equal names/prefixes do not. Unknowns display identifiers. Local manifests/preferences/removal records still supply explicit fallback names; Launch Services still excludes installed apps. No remote lookup/catalog is used.

130 tests / 16 suites passed after final search/fallback polish. Native isolated GUI verified friendly names, parent/helper grouping, unrelated prefix separation, Identifier mode, name/identifier/path search, refresh preservation, verified-only bulk selection, possible-only individual review, simulated cleanup completion/OK/refresh, and Force-Quit-only neutral heading/result/OK restoration. QA launched without test arguments through a separate bundle identifier and persistent MacventoryQABundle marker; it remained isolated and simulated. Real applications/processes/user data were untouched. Version 1.0.0/build105. Local app/ZIP/DMG signatures, integrity and checksums pass; publication review has 100 inputs/zero findings. Refresh the exact-manifest source archive/checksums after any subsequent edit. No commit/push/tag/publication authorized. Existing index/staging changes remain preserved.

## Current in-progress checkpoint — management results and leftover grouping

Preserved all pre-existing staged and unstaged work. The new working-tree correction changes the management sheet title from uninstall-specific wording to the application name and compacts result copy into status plus non-duplicated operation details. Leftover Data now defaults to Application grouping with an Identifier switch; only removal-record/metadata-backed names combine identities, and every selected candidate retains its own identity for live revalidation. Partial scans now record structured location/reason/permission/retry issues. The UI blocks only candidates under a failed source, while independently scanned candidates still need exact identity, ownership, installed-app, symlink, containment and Finder preflight checks. Possible-related files remain individual-only; protected data remains unavailable.

Focused Swift verification passed: 32 tests in 3 suites; the complete safe suite then passed 123 tests in 15 suites. A fresh local arm64 app, ZIP, DMG, source archive and checksums were generated and verified (ZIP, checksum, DMG, source archive, signature, publication review: 97 inputs/zero findings). A fresh native GUI run remains blocked: computer-use bound to an already-open non-isolated Macventory window with the same app identity, so no interaction was attempted. No real process, installed application, package, cache, preference or user file was modified. No commit, stage, push or publication has been performed. Next: when the non-isolated window is closed by its owner, launch a uniquely identifiable isolated build for the final GUI assertions.

## Current handoff — build 104 management UX and leftovers correction

Preserved the scanner architecture, ten source categories, original branding and licensing. One local `ManagementPresentation` now owns the unified **Uninstall [Name]** sheet, replacing competing reachable management previews. Cancel/OK dismiss the actual sheet; `onDismiss` clears the model. Terminal results have one OK, no repeatable execution controls, and refresh is deferred until dismissal. Discovery/size work runs in detached utility tasks with generation guards. `ManagementSession` serializes single-use confirmation and reports ordered completed/partial/failed/skipped/cancelled steps. `NativeTrashRequest` bounds callback waiting and ignores duplicate/late callbacks; timeout explicitly leaves the native request outcome unknown.

Generic Leftover Data scans exact Library identifiers and bounded local manifests, with current-inventory/Launch Services exclusion. Only groups with existing candidates are actionable. Recent removal identity records remain separate; stale/retrospective ownership is possible-only. Shared containers stay protected, personal folders require nomination, and incomplete scans retain observations as stale while blocking cleanup. Cleanup has a trash-icon/text review action, exact paths, individual confirmation and one post-result refresh. Simulated removals affect only in-memory QA view state; fixtures stay on disk.

121 tests / 15 suites pass; opt-in live integrations skipped. Native synthetic checks cover context menus, individual/all-three operations, success/failure/Cancel/OK/reopen, restored main-window interaction and leftover group removal. Updated XCUITest source is retained but cannot run without full Xcode. All process/Trash/uninstall QA uses simulation; never run a live removal adapter to resolve unverified behavior. Original normal app instances were not quit or modified by GUI QA. New test bundles use separate QA app identifiers and isolated fixture roots under ignored build paths.

Version stays 1.0.0; build is 104. Rebuild app, ZIP, DMG, reviewed source archive and checksums after documentation/screenshot edits. No commit, index operation, remote change, tag, push or publication is authorized. Existing staged additions predated this correction pass and are preserved.

Final QA also exercised partial cleanup with later uninstall skipped and OK-only dismissal, plus Light/Dark leftover layout. A public synthetic overview screenshot is explicitly allowlisted; no personal path is visible. The normal and running QA rows now have different synthetic bundles/identifiers, and production running-state checks repeat before each data item. Settings footer presentation belongs to the split-view root; QA cache maintenance is disabled even in safe-QA mode. Full cursor/minimum-window-size and XCUITest automation remain limited by the available environment.

Final app/ZIP/DMG and checksum/source artifacts rebuilt successfully, with 97 reviewed inputs and zero publication findings. ZIP integrity, DMG checksum, strict signature/resource checks and ZIP-extracted simulated native GUI smoke passed, including Settings footer/search/filter and cleanup OK/refresh. No staged/index/history/remote changes were performed. A stale UI handle reopened its QA copy without test arguments during a read-only lookup; no management action ran, but a normal scan/cache write may have occurred. Do not claim real cache hashes stayed unchanged. Avoid observing a closed app through an old computer-use handle; bind the explicitly launched QA path and verify its test flag/banner before every interaction.

## Current handoff — application management and leftover data, build 103

Added `ApplicationManagement.swift` and native SwiftUI management/Leftover Data views without changing the existing inventory scanner architecture. Exact bundle-ID discovery is bounded to normal user Library locations; name-only support/cache matches are possible-only; group containers are protected; personal locations require a picker-driven explicit review. Confirmed real uninstalls retain only minimal identity/source/evidence/time data in `removed-applications.json`; the installed inventory remains separate. Retrospective Kimi discovery uses `com.moonshot.kimichat` solely as an identifier-led investigation hint.

QA remains simulation-only for all process, Trash and uninstall actions. Do not force quit, remove, move, clear, or inspect real user data to extend this pass. Rebuild project/package artifacts after documentation changes; do not commit, tag, or publish without owner approval.

## Resumed changes

Preserved existing SwiftUI/core/scanner architecture and all ten sources. SPEC v1.5 supersedes earlier name-typing/appearance-preview UX. Checkbox confirmation is plan-UUID bound with fresh validation/single-use/concurrency protection. Preview presentation is local to its requesting window, preventing shared-model sheets in multiple windows. Native row double-click/Return opens preview, single-click details/right-click actions preserved. Blocked package/system/demo guidance cannot execute. Settings uses committed appearance until Done; Cancel/Escape/native-close discard drafts. Version comes from Resources/Info.plist:1.0.0/build101.

83 tests / 11 suites pass with live tests enabled, including 12 uninstall tests (all non-destructive). GUI verified single/double click, Return, right-click menu, header nonactivation, checkbox reset/gating/cancel/simulated success, blocked package and synthetic system component. Appearance staging in both directions/System, Escape/Cancel/native-close, Done/reopen and no appearance rescan verified. Real preferences/cache hashes match before/after. No real removal, installed-software modification, user-data deletion or cache clearing.

## Packaging and final QA completed

Final optimized arm64 app/ZIP/DMG 1.0.0/build101 verified. Native Finder two-icon background/arrow/instructions survived read-only final-image mount after staging image detach. Applications link points to /Applications; installation copy simulated only into build/1.0-install-test, executable/signature match and app launches. ZIP matches/launches; About 1.0.0 checked. No development runtime library dependency. Release-only stripping removes local debug/object paths before signing; final privacy check must remain clean. Five public synthetic/native-installer screenshots refreshed. 476 independent read-only inventory checks passed again. Source archive/checksums/manifest refreshed at handoff after final docs. Older 0.1.0 artifacts archived under ignored build/pre-1.0.0.

## Authorization and pending checks

Local/advertised remote main remains 55f7ea9febc821436aad73b14f86c3c4d92f42f8; existing SSH origin preserved. Only LICENSE tracked; source untracked; no index/history/settings changes. LICENSE/NOTICE retained. No commits/tags/push/releases/remotes/metadata changes authorized. Final manifest contains 85 reviewed inputs (84 proposed additions plus unchanged LICENSE). Regenerate after future edits.

Never invoke a real removal adapter during QA. Use --demo for public screenshots and --ui-testing for synthetic simulated success. Do not retry Xcode/Apple authentication or request paid membership/notarization. Full Xcode/XCUITest unavailable; VoiceOver not enabled/navigated, minimum-OS/clean-machine and actual destructive removal remain unverified. Intel optional; arm64/M4 Pro primary. Free/ad-hoc signing is policy, not a packaging blocker.

## Final handoff checks

All 83 tests pass (11 suites, 3 live read-only integrations,12 uninstall tests (all non-destructive)). Final symbol-stripped app/ZIP/DMG signatures/resources/integrity pass; extracted final ZIP launched and About 1.0.0 visually rechecked. Final binary has zero developer home paths. Original icon sources/ICNS/LICENSE unchanged. Source archive contains exactly 85 reviewed files with matching SHA-256 hashes; checksum file verified. Real configuration/cache hashes unchanged through final QA. No source changes after final build.

## Latest focused fix

1.0.0/build101: final read-only uninstall success state, exact two-line production message, single OK; simulation clearly labeled. 83 tests pass including exact-copy and decodable-brand-resource regressions. Actual simulated GUI verified controls disappear/OK dismisses. Shared official assets and post-launch running icon assignment restore reliable branding; toolbar/About/DMG Finder visually verified, ZIP reports icon loaded/assigned. Direct Dock screenshot unavailable, so do not claim visual Dock verification. Original assets intact, no global cache purge. Final package/source/checksum/manifest refreshed after docs. Real cache/settings hashes unchanged. Prior 476-check inventory audit was not repeated in this focused pass. No real uninstall, installed-copy modification, commit or publication.

## Repository cleanup only — build 101 preserved

No UI/branding/source/test changes. Removed only root, Design and Sources .DS_Store metadata after signature/reference checks. Archived ten generated Resources/Macventory.iconset PNGs and ten unreferenced root QA logs under ignored build/cleanup-archive. Retained both original Design PNGs, approved ICNS/toolbar/installer derivatives, five public screenshots and all source/tests/docs/required scripts. No ambiguous build evidence deleted.

Root-scoped iconset ignore added. Source packaging now uses the reviewed publication manifest rather than recursive folders, preventing ignored files from reentering source archives. 83 regression tests/11 suites pass; native app/ZIP/DMG rebuild passed with intermediate iconset absent. Small ZIP --demo GUI smoke passed; no repeated uninstall QA. Real settings/cache hashes unchanged. Final manifest 85 files (84 additions plus unchanged LICENSE), exact source-archive hashes/checksums verified. No regressions or Git mutations. See CLEANUP.md for full retention/removal evidence.

## In progress — standalone Move to Trash

Kimi's inferred source fails the verified-source guard; ordinary discovery also never sets the old manual eligibility attribute. Preserve inferred source attribution. Implement independent bundle/ownership eligibility, native NSWorkspace recycle, revalidation and simulation tests. Never invoke a live removal adapter or Trash installed software. Build101 UI completion/branding remain protected.


## Current handoff — standalone Move to Trash, build 102

Completed independent standalone eligibility (source attribution stays inferred), cancellable fresh eight-source ownership audit without cache/sizes, strict standard-root/current-owner/local-volume/permissions/metadata/executable/linked-path/service-component protections. PKG audit limits now fail closed. Native discovery retains symlink/alias evidence after canonicalization. Fingerprint binds bundle/executable/parent identities and metadata. Fresh validation repeats ownership and running checks; live adapter repeats validation and performs immediate main-queue identity/running checks before one native NSWorkspace recycle request. It requires a returned target mapping and has no permanent-delete/elevation/cleanup fallback.

Operation-specific Move to Trash vs Homebrew Uninstall controls preserve checkbox/reset/single-use and exact OK-only completion. QA eligibility is explicitly labeled simulated and rejected by live recycling. Isolated fixture bundles live beside the built QA app (under ignored build), avoiding macOS /var symlink ancestors. Real inventory/cache/preferences are not used by fixture mode.

91 tests / 12 suites pass, including 3 live read-only integrations and all prior removal safety tests. Final native build102 GUI verifies inferred fixture eligibility, checkbox gating, simulated success/OK-only/dismissal, reset and cancellation. About/icon smoke passes; synthetic bundle remains. Kimi read-only planner audit passes and offers Move to Trash while keeping inferred attribution; no real removal or real-app confirmation occurred. Detailed owner-specific evidence stays ignored under build/.

README/SPEC/security/source matrix/UNINSTALL/verification updated. Xcode project regenerated/plist syntax valid. Local app/ZIP/DMG/source/checksum artifacts and exact publication manifest rebuilt for build102; 87 publication inputs (85 existing tracked files and 2 new files). No stage/commit/push/tag/publish or unrelated project edits. Full Xcode/XCUITest, actual destructive removal/Trash restoration, absent-manager live behavior and direct visual Dock inspection remain pending. Do not run live removal to resolve those gaps.

Current repository HEAD inspected in this pass is 1cc7ac49d37ee1273eb6a649bb41456e633acbbf. The earlier LICENSE-only/55f7ea9 statements above describe historical handoffs; the current baseline already tracks 85 files. This execution made no commits or index changes.

Final packaging checks: ZIP extraction, signature, build102/executable/ICNS matches and actual demo GUI pass. DMG integrity/read-only mount contents/signature/build102/icon checks pass; detached safely. Release executable has no developer home path. Manifest/link/privacy review passes with 87 inputs. Source archive/checksums regenerated after final docs. No new source changes after the passing 91-test run and native build.


## Current handoff — GitHub CI repair candidate, build 102

Working baseline a7d2a9c; original failed run used older 1cc7ac49. Split InventoryView's large body into typed view/toolbar boundaries, preserving state, sorting/filtering/table interactions/settings/uninstall presentation. Both workflows now select standard macos-26 arm64 and pinned preinstalled Xcode 26.5, verify Swift 6.3/SDK 26.5 and log environment details. Swift helper honors DEVELOPER_DIR and resolves Swift via xcrun. Shared scheme and generator set --ui-testing on the Xcode unit-test app host. Synthetic fixtures/simulation only in CI; opt-in live checks disabled. Primary build/unit/package checks and explicitly reported XCUITest run are separate jobs; a failed GUI attempt remains a failed/incomplete result.

Fresh local SwiftPM build and 91-test report (3 live integrations skipped) pass. Optimized arm64 packaging and artifact validation pass; shell/YAML/XML/plist/whitespace/publication checks pass. No local Xcode retry, Apple authentication, real uninstall, settings/cache clearing or new GUI verification. Revised cloud execution awaits approval to commit/push; do not mistake prepared workflows for executed checks. See [CI.md](CI.md). No staging/commit/push/tag/release occurred in this repair. Existing earlier execution evidence remains historical.


## PR #1 — confirmed GUI execution investigation

Run40028914665/e5db815 passes the entire primary native pipeline, including Xcode unit tests and artifact packaging/validation. Actual GUI run executes10 tests with11 failure records. Downloaded xcresult hierarchies show inventory.table as Outline and the settings toggle as CheckBox. Screen recordings show fixed-height settings footer beneath the Dock; Cancel/Done clicks hit System Settings, leaving the same draft open and preventing About presentation. No cross-test settings leak or search/refresh bug is demonstrated by these failures.

Local corrections adapt Settings presentation height to usable display, identify the actual inventory/toggle roles and require visible footer controls, sheet dismissal and About window creation. All10 tests remain; assertion sites55→69. Local SwiftPM build/91-test report (3 live integrations skipped), UI Swift parser and whitespace/static source checks pass. Corrected hosted GUI execution remains pending approval to commit/push. Version1.0.0/build102, Xcode26.5, removal safety and fixture-only execution unchanged. No real cleanup/removal, Git commit/push/merge or Apple authentication. See [investigation](XCUITEST-INVESTIGATION.md).


## Current handoff — compact screen, baseline0811660

PR40031376348 native all passes; GUI8/10 pass. Push40031370109 sameSHA native all passes; GUI4/10 pass. Both bundles/logs downloaded and decoded. PR outer1050 width contains1337-wide split rootedx=-143; push actual1320-wide window beginsx=-148 on1024 display. Settings/Columns physically inaccessible. Source is on-screen but native header hit testing/auto-scroll fails, so do not equate it with an off-screen control or claim its separate AppKit root cause proven.

Local native window containment, compact VSplitView details, fixed compact details actions and actual-control hittability assertions implemented. All10 GUI methods remain. Build/fixture tests and four compiled geometry-policy cases pass; corrected hosted GUI remains pending approval to commit/push. Xcode26.5/build102/safety code untouched. See [COMPACT-LAYOUT.md](COMPACT-LAYOUT.md) for limits and next checks. No commit/push/merge/tag/publication or real removal/cleanup.


## Current handoff — Source header, baseline271cd13

Latest PR40039301815 and push40039297430 pass native; GUI9/10. Full artifacts/logs reviewed; Source frame544,158,137,28 is visibly contained but XCTest hittability fails after Version twice. Actual hostmacOS26.6.2/Xcode26.5/SDK26.5. No full ancestor/pre-sort snapshots retained in those bundles. Native semantic/header-hit probe using actualInventoryView in isolated --ui-testing works locally onmacOS27; this does not prove affected-runtime behavior or XCTest success.

Confirmed helper bug fixed: failed existence/hittability throws via failing XCTUnwrap and cannot continue into click. Phase screenshots/full accessibility trees and real row-order/selected-identity assertions added to existing six-header/two-directions test; all10 methods retained. Core Source reverse/header-switch assertions added. Local build/91-test report (3 live integrations skipped), UI syntax and whitespace checks pass. No unsupported production workaround, layout change, safety/version/toolchain change or Git publication. A fresh approved hosted run is needed to classify/fix the remaining native-vs-XCTest cause. See [SOURCE-HEADER.md](SOURCE-HEADER.md).


## Current handoff — new diagnostic evidence, baseline d93cf87

PR40041664648 native passes, GUI9/10. Retained phase trees independently confirm only Version hittable BEFORE selection; all other headers false despite visible, contained bounds. No state change after Details or Version sorts. Do not repeat prior layout/sequence attribution. Confirmed helper now stops on its single failing XCTUnwrap.

Four-case standalone native proxy diagnostic prepared under Diagnostics/ plus scripts/probe-header-proxies.sh; CI runs it after GUI and uploads logs without overriding GUI failure. Compare key-path/custom/customized/actual inventory on macOS26.6.2. LocalmacOS27 comparisons expose AXPress on all headers, native Source hit results/directions/selection work; not an XCTest pass or proof on the affected runtime. Local build/91-test report (3 live skipped)/syntax checks pass. All10 GUI methods and production source/build102/Xcode26.5/safety remain unchanged. No commit/push/merge or real removal. See [HEADER-PROXIES.md](HEADER-PROXIES.md); hosted classification still needs approved push.
