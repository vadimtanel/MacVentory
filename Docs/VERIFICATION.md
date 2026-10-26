# Verification — Macventory v1.1.0

## Current documentation candidate — 26 October 2026

Source metadata is **1.1.0 / build 108**, with configured macOS **13.0** minimum. Documentation preparation starts from clean `main` at `a5a66efcaf2f1b06c3f32bb104e6125239f831c9`. Version values are not incremented. v1.1.0 is upcoming; the owner will create the tag and publish the release separately.

| Evidence category | Established evidence and limits |
|---|---|
| Implemented | Merged source-aware uninstall levels/adapters, installation health, missing-app/historical records, application management, separate Leftover Data, safeguards, diagnostics and packaging. Implementation does not prove real effects. |
| Recorded local synthetic tests | The [trace-handoff report](SELECTION_TRACE_HANDOFF_VALIDATION.md) records 225 registered tests across 24 suites: 222 passed, 0 failed, 3 intentional live-test skips. Earlier 148/207/221/222 totals belong to their named snapshots; they are not new runs for this documentation commit. |
| Recorded read-only live tests | Native/Homebrew/receipt observations and earlier opt-in read-only integration passes exist in the reports. They do not test removal. |
| Hosted starting-commit evidence | [Run 40309598774](https://github.com/vadimtanel/MacVentory/actions/runs/40309598774), attempt 1, for `a5a66ef`: **overall failure**. Native passed SwiftPM, Xcode app/test compilation, hosted units, packaging and artifact validation. UI failed actual-count/order verification and final reporting. Primary GUI/header step summaries alone do not establish a full 16-case pass; raw evidence needs inspection. |
| Documentation commit and stabilization | Commit `3c99886e9fe2f625279e9fe75aab83dc9274e0c1` is preserved on the existing local/remote stabilization branch. Its [hosted run 40316125739](https://github.com/vadimtanel/MacVentory/actions/runs/40316125739) failed the same execution-level case (15/16 passed). The original documentation review remains a dated record. The proposed local test/CI patch has no hosted validation; see [stabilization findings](STABILIZATION_SELECTION_REVIEW.md). |
| Real effects | Actual provider removal, native Finder Trash/restoration, real Force Quit, vendor/Steam completion and real signed-helper authorization/lifecycle remain unverified. Fake effects are not destructive safety evidence. |
| Distribution/runtime | arm64 is primary. Recorded local runtime is M4 Pro/macOS 27.0.1; macOS 13 is configured, not runtime-tested. Intel/universal, quarantined clean-machine Gatekeeper and full spoken VoiceOver remain unverified. Default packaging is ad hoc, not Developer ID/notarized. |

**DOCUMENTATION READY** requires zero publication findings and reviewed Markdown/links/diff. **RELEASE READY is not established.** Require complete hosted CI on the exact final commit (all 16 original primary GUI cases plus the proposed selection regression, sequence checks and diagnostics), verified matching assets and review/resolution of applicable remaining gates before tagging. See [CI](CI.md), [release process](RELEASING.md) and the [disposable-environment verification plan](UNINSTALL_FOCUSED_VALIDATION.md).

This documentation-only pass performs no app build/package generation, application launch, destructive test, manager mutation, process termination, cache clearing or privileged-helper activation. It does not validate earlier local packages as v1.1.0 artifacts.

## Historical verification log — v1.0.0 development builds

All sections below retain their original build identifiers, counts and pass-specific claims. Headings such as “current”, “latest” and “blocked” refer to the named historical pass, not the v1.1.0 documentation candidate. Later source/audit reports and the current summary above take precedence for current behavior; these records are not rewritten as newer tests. Earlier statements excluding any helper/elevation predate the separate MacPorts implementation.

## Build107 — current verification

Final packaging VERIFIED: build107 app signature, ZIP compressed-data integrity, DMG checksum, artifact SHA-256 checksums and all 106 exact reviewed source-archive inputs/hashes pass. Publication review reports zero findings. The final safe suite again passed 148 tests / 19 suites after the corrected Settings presentation.

148 tests / 19 suites passed. Added meaningful tests for sidebar union/normalization, overlapping-source deduplication, search filtering, library/source combinations, system filtering, exact whole-folder submission and stage-specific permission diagnostics. Native Sidebar QA uses a separate identity and persistent isolated marker. GUI verified two selected sources with combined rows and a category count, search narrowing that union, Leftover Data separately selected, detailed simulated access-denied result with help and OK, retained per-item diagnostics, explicit personal-discovery-off status, corrected Scanning Settings shortcut, and enabled synthetic personal folders as whole targets. No actual Trash request, privacy grant or owner-data change was performed.

The real Share-container error cannot be attributed to TCC versus preflight from the old generic message. Metadata confirms current-user ownership and owner read/write on the folder and its parent; the new build reports which stage failed. Privacy access is controlled by macOS and the user. Actual Finder Trash and real privacy dialogs remain unverified. Build107 local release artifacts are regenerated after final documentation; no publication is authorized.

## Build106 — stale cleanup and optional personal discovery

Packaging VERIFIED: final arm64/build106 app signature, ZIP compressed-data integrity, DMG checksum, all artifact checksums and 104 exact reviewed source-archive inputs/hashes pass. Publication review reports zero findings. No publication or Git index/history mutation was performed.

Final result: **143 tests / 18 suites pass**. A further generic test covers a distinctive folder-name prefix of an identifier component when the original friendly name is lost. Such a result is explicitly uncertain, possible-only and manual-only; it does not invent a display name. Broad names are excluded from this heuristic, and ambiguous associations remain protected. This supersedes the earlier 142-test checkpoint below.

VERIFIED: 142 tests / 18 suites pass; real-machine integrations remain skipped. New tests cover missing targets without submitted deletion, independent cleanup after permission/identity failures, unknown-outcome stop/no retry, protected/duplicate target blocking, confirmed-missing reconciliation and updated totals/empty-group removal, inconclusive/denied retention, dangling ancestors, combined-operation missing-item results, default-off/backward-compatible settings, bounded personal enumeration, shallow name association, manual-only classification, permission details and ambiguous/symlink protections.

Actual native synthetic GUI passed: Already Removed/No Longer Exists result with no deletion claim, OK restoring interaction and removing an empty group; mixed absent/simulated move/permission-denied results and corrected counts/sizes while retaining denied/protected candidates; protected checkbox disabled; default-off Scanning setting; enabling bounded Documents/Downloads suggestions grouped by known application; injected Desktop denial in View Scan Issues; no automatic verified selection of personal folders; exact-path confirmation initially disabled until acknowledgment; Cancel; disabling the setting removes suggestions and clears the personal-only warning. Final result-copy deduplication is compiler-verified after this native pass.

SAFETY: all GUI uses the separately identified Cleanup QA bundle, persistent isolation marker, synthetic home and mocked outcomes. Fixture files remain present; simulated missing observations and moves change view state only. No real application, process, package, cache, setting or personal file was modified. Actual Finder Trash and real TCC dialogs remain untested. Personal associations use retained names, exact identifiers or bounded distinctive identifier-component leads; arbitrary fuzzy/vendor-specific folders and deeper personal hierarchies remain outside scope. Local build106 app/ZIP/DMG/source/checksums are regenerated after final edits; publication remains owner-controlled.

## Identity regression correction — latest evidence

Final regression result: **131 tests / 16 suites passed**, including exclusion of recorded extensions when their parent is reinstalled or registered. This supersedes the 130-test checkpoint below. Packages are regenerated with this safeguard.

VERIFIED: 130 tests / 16 suites passed, with real-machine integrations skipped. New synthetic coverage includes history persistence and Codable storage, external removal with missing preferences/cache bundle, removal records, pre-install unknown fallback, retained names without ownership changes, reinstallation exclusion, embedded extension parentage, unrelated vendor/prefix identities, renaming, conflicts, expiration/future timestamps, grouping modes, exact-ID manifest display names and QA isolation without arguments. Version remains 1.0.0; this identity correction is build 105.

Actual isolated GUI verified Orchard Notes from retained metadata, Retired Studio with its recorded Share extension, unrelated similar identifiers remaining separate, technical Identifier mode, search by name/identifier/path, refresh preserving names, verified-only bulk selection leaving the possible helper unchecked, manual possible cleanup confirmation/simulated completion/OK/refresh, and Force-Quit-only application-name heading/completion/one OK/restored interaction. The separately identified QA app was launched without arguments and still used fixtures and simulation via a persistent bundle marker. This supersedes the prior GUI-targeting blocker. Full XCUITest remains unavailable without full Xcode; production destructive operations remain intentionally untested.

Unresolved identities: apps removed before any retained name or local metadata exists keep their identifier. Similar helper prefixes cannot reconstruct parentage. No hardcoded product catalog, internet lookup, user-label editor or arbitrary undocumented provider format was introduced. No real installed application, process, cache, preference or personal file was changed during this verification.

Build105 local release verification passed: arm64 app, ZIP compressed-data integrity, DMG checksum, SHA-256 checksums, strict app signature and normal release bundle identifier. The separate QA copy has the persistent isolation marker. Publication review reports 100 inputs and zero findings. Source archive is regenerated from the exact reviewed manifest after final document/test changes. No commit, tag, push or release was made.

## Follow-up management and leftover-data correction — current working tree

**VERIFIED:** the focused Swift suite passed: 32 tests in 3 suites. It covers operation-specific result copy, generic application-versus-identifier grouping, preservation of per-candidate identities across presentation grouping, structured partial-scan issues, manual possible-file selection, protected-data blocking, and existing filesystem/preflight protections. Tests use only isolated synthetic filesystem fixtures and simulated executors.

**IMPLEMENTED BUT UNVERIFIED:** the native UI now exposes **Group by: Application/Identifier**, structured scan-issue details and retry controls, and allows individually reviewed possible files whose own source was scanned successfully even if another Library source failed. The revised application-name result sheet and the new controls have compiled but have not yet received a fresh native GUI pass in this correction cycle. UI automation found an already-open non-isolated build with the same app identity and could not safely target the separately launched `--ui-testing` process; it was left untouched.

**Safety boundary:** a partial scan does not grant automatic selection. It only avoids a global disable for an independently checked candidate outside the failed location; possible files always require individual selection and confirmation, protected files stay blocked, and all selected paths are freshly validated before a live Finder request. No real application, process, package, cache, preference or user file was accessed or modified.

**Packaging:** a fresh local arm64 app, ZIP, DMG, source archive and checksums were generated after this correction. ZIP integrity, ad-hoc signature, checksum verification, DMG checksum/integrity and source-archive readability passed. The publication review reported 97 inputs and zero findings. These are local artifacts only; no commit, tag, upload or release was created.

## Build 104 correction pass — current evidence

**VERIFIED:** 121 Swift tests / 15 suites passed. Three opt-in real-machine integrations were intentionally skipped. New coverage includes all seven operation combinations, acknowledgment/single-use/reopening, concurrent confirmation rejection, cancellation, preflight/async failures, partial results, stalled Finder callback timeout and ignored late callbacks, QA-only executor selection, changed/missing/duplicate/nested targets, zero-result history, no-history discovery, installed/reinstalled exclusion, stale evidence, local manifests, personal-folder exclusion, denied/partial/empty/cancelled scans and refresh after external fixture removal. Existing uninstall restrictions and scanner regressions remain.

Root cause confirmed in build 103 source: `InventoryView` maintained a separate `showManagement` Boolean while `closeManagement()` only cleared `managementItem`. The `if let` sheet content vanished while the Boolean kept its modal presentation alive. Management also had no terminal branch or OK button, retained executable controls after completion, and synchronously enumerated data sizes on the main actor. The correction uses one item-based local sheet, immutable single-use requests, explicit terminal results, real sheet dismissal and background discovery. Native Trash callbacks have a watchdog; timeout is an unknown outcome, never a claim of cancelled filesystem work.

**Native GUI verified with synthetic fixtures:** running/non-running context menus; correct absence/presence of Force Quit; preserved Copy/Reveal entries; no redundant menu items; single-click details; double-click unified title; Force-Quit-only, Clear-Data-only, Uninstall-only and all-three simulations; initially unchecked review; Select All Verified excluding possible data; successful result with one OK; OK restoring the main window; reopening fresh state; Cancel removing the sheet; failure result with one OK; generic leftovers with actual candidates; no empty-history group; cleanup summary/acknowledgment; cleanup simulation removing its resolved group on one refresh while retaining another group. Fixture files remained present. Separate QA bundle identities avoided controlling the owner's running Macventory.

**IMPLEMENTED BUT UNVERIFIED:** production Force Quit, real Homebrew removal and Finder Trash/restoration; every vendor's undocumented files; real-machine retrospective discovery accuracy; complete cursor/VoiceOver audit; minimum-OS runtime. QA never invoked these destructive adapters. Actual installed-app icon loading remains native and cached; a fixture with a real bundle ICNS and generic CLI fallback was visually inspected. Late callback handling is tested with injected callbacks, without a native Trash request.

**BLOCKED:** automated XCUITest execution requires full Xcode; the active environment has Command Line Tools. The XCUITest source was updated and expanded, and native computer-use checks were performed independently. The supplied text referenced a screenshot but no new screenshot file was attached; the previously packaged binary found locally did not match the build-103 advanced UI, so the original owner's exact modal instance was not replayed. The faulty state transition is established by source tracing and the corrected flows were exercised directly.

**NOT IMPLEMENTED / intentionally unsupported:** automatic sweeps of personal folders/external volumes, automatic deletion of inferred/shared data, permanent deletion, bulk uninstall, privilege escalation, rollback guarantees and one-click cleanup of every unknown Library directory.

Additional final GUI evidence: the injected partial-cleanup run reported Force Quit completed, Clear App Data partial and Uninstall skipped, with one OK restoring interaction. Light and Dark Mode leftover layouts were visually inspected. A reviewed public screenshot shows only synthetic group names and no candidate paths. The Settings footer presentation was moved to the split-view root so it also works from Leftover Data. Attempted corner dragging did not resize the window through the available automation, so minimum-size resizing remains unverified in this pass. Cache clearing is also disabled at both UI and model levels in all QA modes.

Final release packaging passed: native arm64 1.0.0/build104 app, ZIP, DMG, source archive and checksums; ZIP compressed-data integrity, DMG checksum and strict app signature checks succeeded, with 97 reviewed publication inputs and zero pattern/link findings. The ZIP-extracted binary matched the build before its disposable copy was given a distinct QA display name/identifier and re-signed. That copy launched with `--ui-testing`; native GUI verified the Settings footer from Leftover Data, search/confidence filtering, cleanup review/simulation, OK dismissal and refreshed empty-filter state. Original branding/license/NOTICE hashes match HEAD.

QA caveat: refreshing a stale computer-use handle after closing its test app automatically reopened that QA copy without launch arguments. Read-only UI snapshots then showed real inventory; no management or cache-clear action was invoked. A normal scan may have rewritten the shared inventory snapshot, so this pass does **not** claim the real cache is unchanged. Process-path/argument checks and a freshly bound, uniquely named ZIP copy were used for the remaining checks. The installed application in Applications was not quit or removed.

## Application management pass — build 103

Implemented non-destructively: independent native process identity planning for Quit/Force Quit; source-aware exact-ID app-data discovery; verified/possible/protected candidate classification; minimum recently-removed identity persistence; retrospective Kimi-ID discovery hint; manual user-selected personal-location review; nested/duplicate path normalization; native Trash adapters; and a combined management/Leftover Data UI.

Focused fixture tests cover exact support/container/preferences/cache data, group-container protection, manual Documents review, invalid identifiers, retrospective hints, minimal removal records, duplicate nesting, and simulated cleanup. Existing uninstall simulation regressions remain. No live process termination, uninstall, data move, Kimi inspection, preferences/cache reset, or other destructive operation was performed in this pass. Live process and Trash behavior therefore remain implemented but unverified.

**Local build and review candidate.** Version1.0.0 does not establish every platform/distribution check. No commit, tag, push, release, remote or repository-setting change was performed. No real uninstall, package cleanup, installed-software modification, user-data deletion or real inventory-cache clearing occurred.

## New header-proxy evidence — baseline d93cf87

Run40041664648 passes native and9/10 GUI tests. Full retained phase trees now confirm Name/Source/Size/Installed/Last Opened are not hittable before selection; only Version is hittable. States remain unchanged after Details/sorts. No layout or sequencing cause is established. A four-case native proxy comparison is prepared for the same hosted runtime; original ten GUI tests remain unchanged/failing until proven otherwise. Local comparison/build/fixtures pass, but affected-runtime native-vs-XCTest classification remains pending. See [HEADER-PROXIES.md](HEADER-PROXIES.md).

## Persistent Source hit-testing investigation — baseline271cd13

Both latest runs pass the native pipeline and9/10 GUI tests. Source is fully visible but not hittable after Version twice; generic compact-window fixes are no longer supported by the evidence. Current attachments lack full ancestry and earlier phase states. A local synthetic actual-InventoryView probe on macOS27 activates native Source in both directions and retains selection, but cannot classify the macOS26.6.2/XCTest defect. Only the confirmed clickVisible fall-through bug and test diagnostics/assertions are corrected locally. Root framework cause and hosted GUI success remain unconfirmed. See [Source header report](SOURCE-HEADER.md).

## Latest compact-display correction candidate

Both0811660 workflows pass primary native validation. PR40031376348 runs10 GUI tests with2 failures; push40031370109 has6 failures. Full logs/xcresult/video evidence shows window/content overflow; Source is visibly on-screen but native hit testing fails. Display-contained window geometry and native vertical details on compact widths are prepared. Local build/fixtures and four actual geometry-policy cases pass; corrected hosted GUI and larger-screen rendered interactions remain unverified. See [compact layout report](COMPACT-LAYOUT.md). No commits or real removals in this investigation.

## Confirmed cloud native pass; GUI runtime corrections pending

[Run 40028914665](https://github.com/vadimtanel/MacVentory/actions/runs/40028914665) passed SwiftPM, Xcode application/test compilation, Xcode unit tests, arm64 packaging and artifact validation. The GUI suite actually executed 10 tests with 11 failure records. Full logs and xcresult accessibility/video evidence identify incorrect table/toggle roles and a compact-screen settings sheet whose footer is covered by the Dock. Local corrections preserve all tests and strengthen transition assertions. Local build/fixture tests pass; the corrected GUI suite has not run. See [XCUITest investigation](XCUITEST-INVESTIGATION.md). This supersedes older statements that no hosted Xcode verification has run; it does not claim GUI success.

## CI repair candidate — build 102

See [cloud CI report](CI.md) for original GitHub log evidence, the SwiftUI decomposition, pinned macos-26/Xcode 26.5 environment, checks and pending approval boundary. Fresh local SwiftPM debug build passed. Swift Testing reports 91 tests/12 suites passed with 3 opt-in live integrations skipped in this repair. Optimized arm64 app/ZIP/DMG/source packaging and automated artifact validation passed. No new GUI run, local Xcode run or revised GitHub run is claimed. Real removal, settings/cache clearing and Git publication remain unperformed.

## Current standalone removal pass — build 102

- **91 tests / 12 suites pass**, including all 3 enabled read-only live integrations and 20 uninstall/standalone test methods. All prior safety tests remain; the inferred-source expectation now reflects independently established Trash eligibility. Parameterized cases cover service/provider markers. No real removal adapter is invoked.
- Native optimized arm64 1.0.0/build102 built and launched. Actual isolated GUI verified inferred standalone details, disabled **Move to Trash** until checkbox acknowledgment, cancellation, new-plan reset, simulated success, read-only OK-only completion and OK dismissal. Synthetic target remains present. About/official artwork smoke checked; production success copy remains exact under unit test.
- Kimi was inspected read-only: standard `/Applications` bundle, current-user ownership, APPL identity and executable, no symlink, no App Store/provider/service markers; not running at review. Its bundled share extension remains inside the bundle. Fresh manager/PKG audit passed and the read-only planner reports eligible **Move to Trash**, while its source remains **Direct / Unmanaged · Inferred**. No Kimi GUI confirmation or actual Trash request was performed.
- Original block was the unconditional verified-source guard, followed by an eligibility attribute that discovery never sets. Independent eligibility replaces that unreachable ordinary-app path; it does not invent source provenance.
- Native NSWorkspace recycle is implemented. Permission/result errors, external races and cancellation boundaries are documented in UNINSTALL.md. Actual Trash execution, Finder restoration and real permission dialogs remain deliberately unverified. Xcode/XCUITest and absent-provider live checks remain blocked/unverified as before.
- Build102 app/ZIP/DMG signatures and executable/icon matches pass. ZIP demo launched with all ten fictional source categories and visible official toolbar art. DMG integrity and read-only mounted build102 contents pass; no new DMG GUI launch was performed. Source archive/manifest now contain exactly 87 inputs with matching hashes.
- Detailed local logs and Kimi preview stay ignored under build/. Public screenshot set and original artwork remain unchanged. No real application/package was removed or modified; no user-data deletion or cache clearing was performed. No Git history/index/remote/publication changes.

The build101 checks below are retained as historical evidence; the build102 section supersedes its standalone-support and test-count statements.

## VERIFIED — prior build101 baseline

- **83 tests in 11 suites pass**, with all 3 read-only live integration tests enabled and 12 non-destructive uninstall tests. Four new regression tests cover plan-bound checkbox reset/replacement, concurrency/duplicate protection, unsupported/protected previews and all appearance choices/serialized settings round-trip. Existing tests retained; no destructive executor invoked.
- Actual native GUI: single-click selection/details; native double-click and Return open only a preview; headers do not open removal; right-click Copy Identifier/Reveal/Copy Path/Uninstall preserved. Eligible synthetic app starts unchecked with disabled Uninstall; checkbox enables it, Cancel closes without execution, reopening resets it, injected simulation reports success. Synthetic package and system component previews show identity/reason with disabled Uninstall. Two-window QA confirmed only the requesting window owns a preview and requests from the other window cannot duplicate it.
- Actual Settings colors stay unchanged while staging Light→Dark, Dark→Light and System. Escape, Cancel after multiple edits and native standalone-window closure discard drafts. Done applies committed appearance; reopening retains it. Runtime counters showed one appearance commit/zero rescans, then one separate system-discovery commit/one simulated refresh. Earlier cross-tab batching/validation checks remain applicable. Real persistence was not exercised against owner preferences; Codable round-trip tests verify its representation.
- All ten source categories, synthetic inventory, missing metadata, Light/Dark, official branding and About 1.0.0/creator/license/three exact link destinations inspected. External browser navigation not exercised. Prior full header/filter/column/empty/error/cancel checks are preserved; not every prior GUI path was repeated in this scoped pass.
- Prior 1.0.0 pass independent read-only inventory audit (not rerun for the focused completion/icon fix): **476 checks passed,0 failures,84 records**. Native27 bundles, Homebrew55 formula names/56 kegs,7 casks,3 overlapping PKG discoveries. Names/paths/versions/ownership/logical footprints/receipt provenance compared. See source matrix; absent-provider live verification is not claimed. Detailed evidence stays private under ignored build/.
- Optimized arm64 native app builds using Swift 6.4 CLT/SDK 26.5 fallback. Final app/ZIP/DMG-copy plist versions all **1.0.0/build101**; About agrees. Xcode project regenerated and property-list syntax valid; this is not an Xcode build.
- Final compressed/read-only HFS+ DMG passes integrity verification, mounts/detaches, shows only Macventory and Applications, with large official icon/arrow/readable drag instructions. Applications resolves to /Applications. Background resolves on the final image after the staging image is detached. Finder layout is captured in macventory-installer.png. Finder chrome can follow local preferences; its private metadata format is not a stable Apple API.
- Installation copy simulated using ditto into a project-owned folder, never the real Applications folder. The copied app's executable is executable, bytes match build, ad-hoc signature verifies and app launches. Final copied app's two-window/simulation QA passed. Literal drag onto the real Applications alias was deliberately not performed.
- Release-only symbol stripping removes local SwiftPM object/debug path references before ad-hoc signing; final binary scan reports zero developer home paths.
- Final ZIP extracts, executable matches build and ad-hoc signature verifies; its actual native demo window and About were inspected. Runtime libraries resolve only to macOS system libraries/frameworks, without a development checkout/SwiftPM/Xcode dependency. Minimum-OS runtime remains pending.
- Five public screenshots are actual1.0.0 app/Finder window captures: fictional app inventory only, no private paths, desktop/terminal/Dock/notifications/unrelated windows. Updated main Light/Dark, Discovery, About and installer views. Real preferences/cache hashes match before/after synthetic QA and final screenshot sessions. Original PNG/ICNS hashes unchanged.
- Publication pattern/private-path/local-link review passes; binary Finder metadata checked for private paths. Generated/private evidence, old artifacts, scratch utilities and real inventory stay ignored. Exact current proposed inputs/hashes regenerated under build/. LICENSE unchanged, official repository/history preserved.

## IMPLEMENTED BUT UNVERIFIED

Production source-specific uninstall adapters remain implemented but actual destructive execution unverified. Standalone removal now uses the separate checks described above; unsupported apps retain handoff guidance. Absent MacPorts/Nix/Setapp/Steam/Toolbox and positive App Store provider environments remain fixture-only. Minimum-OS, clean-machine downloaded/quarantined launch, native column dragging/persistence, full keyboard/hover coverage remain pending. M1–M5 intended; only M4 Pro/macOS 27.0.1 runtime tested. Intel optional.

Full VoiceOver navigation was not performed: VoiceOver was not enabled/navigated. AX inspection is not VoiceOver verification. Updated XCUITest cases are prepared, not executed.

## BLOCKED

Full Xcode project build/XCUITest: full Xcode unavailable. No Xcode installation/Apple-authentication retry. Hosted CI has not run; publishing workflow/source awaits approval.

## NOT IMPLEMENTED / intentional distribution choices

No bulk uninstall, automatic cleanup, elevated installer/helper, telemetry/backend/accounts, quarantine clearing or security-policy override. No Developer ID signing/notarization by owner decision; free/ad-hoc packaging is complete and not blocked by paid enrollment. User-initiated Open Anyway, where offered, is documented using Apple's procedure, not exercised automatically.

## Local artifacts

`build/Macventory.app`; `artifacts/Macventory-1.0.0-arm64.zip`, `.dmg`, `.sha256`; `artifacts/Macventory-1.0.0-source.tar.gz`. Source archive/checksums refreshed after final documentation/screenshots; all 87 current archive inputs/hashes match the reviewed publication manifest at handoff. Older 0.1.0 artifacts are archived privately, not represented as 1.0.0.

See [installation](INSTALLATION.md), [uninstall safety](UNINSTALL.md), [source matrix](SOURCE_SUPPORT.md), [publication review](PUBLICATION_REVIEW.md) and [Git plan](GIT_INTEGRATION.md).

## Completion and icon correction — build101

Success copy is exactly `Operation completed.\nRefresh the inventory to verify the remaining installation state.` Production text is unit-tested; no real uninstall was used to display it. The shared success branch is read-only: hides checkbox/operation controls/Cancel/Uninstall and offers only default OK. Actual simulated GUI verified this final state and OK dismissal, retaining an explicit simulation message. Updated XCUITest assertions are prepared, not executed.

Official source ICNS/toolbar PNG were intact, not deleted or replaced. The regression-sensitive code relied on separate optional resource lookups and did not explicitly initialize the running application icon. Shared BrandAssets now supplies toolbar/About, toolbar falls back to official ICNS, and the delegate assigns the official application image after launch. Opt-in final ZIP runtime report confirms officialIconLoaded=true and officialIconAssigned=true. Build 101 distinguishes this corrected bundle from build100. No global icon-cache clearing or installed-copy modification. The exact prior transient Dock/cache condition was not fully reproduced.

Actual final ZIP toolbar/About and mounted-DMG Finder icon visually verified; original asset hashes match app/ZIP/DMG. Package signatures, DMG integrity, executable/resource comparisons and checksums pass. Direct Dock visual capture was unavailable (computer-use timeout); runtime icon assignment is verified, not claimed as a Dock screenshot check. Full Xcode/XCUITest remains blocked. No real software or cache/settings modified.

## Repository cleanup verification (supersedes prior publication count)

Build 101 implementation/assets unchanged by hash. 83 tests / 11 suites pass, including 3 enabled read-only integration tests. Native app/ZIP/DMG build passes without generated iconset intermediates. ZIP extraction/signature/resource checks and small actual --demo GUI inventory/toolbar/About-content smoke pass. No uninstall or real cache maintenance performed; preferences/cache hashes match.

Public set is now 85 files: ten regenerable iconset PNGs archived/excluded, one cleanup report added. Source tar uses the exact reviewed manifest, so ignored/private regenerated inputs are excluded. Archive membership/hashes and checksums verified after final documentation. README/local links, 17 ignore probes, positive public-file checks, Python/shell/Xcode-plist syntax pass. No new regression; existing Xcode/XCUITest/visual-Dock limitations remain. See CLEANUP.md.
