# Macventory 1.0.0 verification — 24 October 2026

**Local build and review candidate.** Version1.0.0 does not establish every platform/distribution check. No commit, tag, push, release, remote or repository-setting change was performed. No real uninstall, package cleanup, installed-software modification, user-data deletion or real inventory-cache clearing occurred.

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
