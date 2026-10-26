# Changelog

## Macventory v1.1.0 — Uninstall & Installation Health (upcoming)

Version **1.1.0 / build 108** is prepared in source; no v1.1.0 tag or GitHub Release has been published. These changes describe the implementation since the public [v1.0.0 tag](https://github.com/vadimtanel/MacVentory/releases/tag/v1.0.0), not completed release validation.

### New Features

- Unified removal previews classify each installation as **Direct Uninstall**, **Interactive Uninstall** or **Guided Only**, with an independent **Protected / Blocked** override and explicit scope/verification details.
- Installation-health Status column, status filtering and **Attention Required** Smart View distinguish current registration, missing/broken payloads, partial states, unverified observations and historical receipts.
- Homebrew missing-app detection retains exact installed cask tokens and expected paths instead of presenting retained registration as a healthy app. Package-only installations remain valid without a GUI bundle.
- Direct adapters for eligible Homebrew formulae/casks, exact MacPorts versions/variants and supported modern mutable Nix profile elements; interactive verified Steam App ID handoff and trusted embedded vendor uninstallers; independently eligible limited PKG/App Store bundle Trash.
- Narrow MacPorts authorization helper implementation requiring matching trusted app/helper signing and per-request administrator authorization for root operations. Default ad-hoc builds cannot use this privileged route.

### Improvements

- Source-specific review/postflight distinguish registration removal, bundle-only removal, Waiting for User, partial, already-absent, failed and unknown results. **Verify Removal** preserves earlier combined-operation results; guided work can be followed by **Refresh Installation Status**.
- Improved cask app/font/owned-binary mapping, renamed/custom app directories, multiple artifacts, physical-copy identity and source conflicts. Manager version and app version remain distinct.
- Application management retains independently eligible Force Quit, Clear App Data and Uninstall actions. Leftover Data remains an optional, separately confirmed review, including after verified removal.
- Installation details, compact action layout, health accessibility labels and UI diagnostics expose evidence and scope. Synthetic selection tracing uses app-owned private files readable by the sandboxed hosted controller.
- Icon generation preserves supplied artwork while improving sizing/Caskroom bundle-icon handling. Packaging includes helper metadata, strips private compiler paths from both executables and validates exact source-manifest contents.

### Bug Fixes

- Prevented changed cask mappings/artifact presence from redirecting a reviewed removal to another physical copy; rejected ambiguous multiple-version cask removal.
- Corrected Nix profile-conflict detection, retained non-app cask artifact warnings and stale/historical reconciliation. Separate copies remain separate regardless of names/identifiers.
- Bound vendor/Steam launches to the selected physical client/tool; restricted generic vendor discovery to embedded associations and strengthened executable fingerprints.
- Preserved earlier management-step results during interactive verification, prevented verification of skipped/completed uninstall steps and disabled dismissal while verification is busy.
- Fixed hosted diagnostic transport across processes and read-only runner sandbox boundaries; these corrections alone do not establish resolution of the original GUI selection regression.

### Safety and Security

- Fresh immutable plans, initially unchecked acknowledgment, single-use confirmation and independent ownership/process/path checks remain mandatory. Health warnings never grant removal authority.
- Authenticated both XPC peers and added per-request OS administrator rights before preflight and immediately before privileged effects; strengthened MacPorts payload/ancestor/ACL checks and bounded replay handling.
- Protected staged running cask bundles and the actual running Macventory copy; rechecked unrelated manager registrations and all registered Steam libraries when verifying results.
- Failed operations never switch strategies or invoke force, zap, dependency removal, garbage collection, receipt forgetting or unreviewed cleanup.

### Known Limitations

- v1.1.0 remains unpublished. Complete hosted CI, including all 16 primary GUI cases and independent diagnostics, must pass on the final documentation/source commit before tagging; native-only or earlier-commit success is insufficient.
- Real provider removal, native Finder Trash, vendor/Steam completion and signed-helper deployment/lifecycle remain unverified. Synthetic tests establish orchestration/validation contracts, not destructive safety.
- Setapp and Toolbox use guidance where trustworthy targeted integration is unavailable. PKG receipts cannot be inverted into uninstall scripts; bundle-only removal may leave external components/data.
- Normal Homebrew uninstall can fail when an expected app is missing; no forced reconciliation is attempted. Nix direct support is limited to named manifest-v3 elements in supported mutable current-user profiles, Nix 2.28–2.35.
- Distribution is arm64 and ad-hoc signed, without Developer ID/notarization. macOS 13.0 is configured, not runtime-validated; Intel/universal, clean-machine Gatekeeper and full VoiceOver are unverified. Privileged MacPorts removal is unavailable with ad-hoc signing.

See [current uninstall support](Docs/UNINSTALL.md), [verification](Docs/VERIFICATION.md) and [release process](Docs/RELEASING.md).

## v1.0.0 — first publicly released version

The [public v1.0.0 tag](https://github.com/vadimtanel/MacVentory/releases/tag/v1.0.0) identifies the first published release. The notes below retain their original local/unreleased milestone labels and build identifiers; they are not separately published v1.0.0 releases. Application management and Leftover Data were already present at this public baseline.

## Historical local development notes — originally Unreleased

- Build107: added Command-click inventory sidebar category unions with search/filter preservation.
- Improved cleanup permission diagnostics/recovery guidance and made whole-folder scope and personal-discovery status explicit.

- Build106: reconciled missing leftover targets with Already Removed results and per-item cleanup outcomes.
- Added default-off bounded personal-folder suggestions with mandatory manual review and permission reporting.

- Retained local application identity history separately from current inventory, with bounded storage and snapshot migration.
- Restored friendly leftover names from local evidence and restricted helper grouping to recorded parent relationships.
- Replaced repeated Unknown application labels with distinct identifiers; kept naming separate from cleanup permission.
- Added a separate QA app identity and persistent fail-closed isolation marker.

- Corrected application-management result titles and reduced repeated completion copy.
- Added Application/Identifier leftover grouping without merging cleanup authority.
- Added structured scan issues, retry affordances and per-candidate partial-scan eligibility.

## 1.0.0 — build 104 local corrections

- Fixed blank/dimmed management sheets by using one item-based presentation and explicit terminal results with OK-only dismissal.
- Unified double-click/Return and Uninstall…; simplified context menus and verified Force Quit visibility.
- Added single-use ordered management execution, partial/failure/cancellation results, process-restart checks and a native Trash callback timeout.
- Replaced hardcoded leftover hints with generic identifier/manifest discovery, installed-app correlation, actual-candidate group filtering, search/confidence filters and a visible trash-icon/text review action.
- Added simulation-only lifecycle/discovery regressions and native synthetic GUI checks; preserved icons, branding, sources and licensing.

## 1.0.0 — build 103 local work

- Added independent native Quit/Force Quit planning, source-aware Clear App Data review, combined management confirmation, and a Leftover Data sidebar.
- Added bounded exact-ID residual-data discovery, minimal recently-removed identity records, explicit manual personal-location review, and retrospective Kimi identifier investigation support.
- Added fixture-only ownership/simulation tests; no live destructive verification was performed.

## 1.0.0 — prepared locally, not published

### Build101 corrections
- Successful uninstall now ends in a read-only result with the exact two-line message and a single OK button; simulation stays explicitly labeled.
- Centralized official branding, toolbar ICNS fallback and explicit post-launch application-icon assignment. Original artwork retained; no global icon-cache purge.
-83 tests pass; toolbar/About/Finder and package resource/signature checks verified. Direct Dock visual capture and Xcode/XCUITest remain unverified.

- Checkbox confirmation replaces name typing, retaining exact plan identity, fresh validation, single-use confirmation and concurrent-request protection.
- Native row double-click/Return opens uninstall preview; single-click selection/details and item-targeted right-click actions remain. Unsupported/protected/demo rows show blocked guidance.
- Settings Appearance no longer previews unsaved values; Done alone applies changes. Cancel/Escape/window close discard drafts.
- Installable two-item DMG with official icon, visual drag guide and Applications link; self-contained arm64 ZIP alternative. Free/ad-hoc distribution and supported manual Gatekeeper exception documented.
- Version1.0.0/build100,81 tests including 11 non-destructive uninstall tests. Full Xcode/XCUITest, VoiceOver, clean-machine and real destructive verification remain pending.


## 0.1.0 — Unreleased

- Native SwiftUI inventory window, persistent installation-source sidebar, table, search, combined filters, sorting and evidence-aware details.
- Independent scanners/adapters for native apps, App Store receipt evidence, Homebrew casks/formulae, PKG, MacPorts, Nix, Setapp, Steam and legacy Toolbox layouts.
- Conservative metadata, physical-installation merging, progressive logical size measurement, smart views, cancellation and local snapshot caching.
- Native icon, settings/About, creator attribution, Apache-2.0/NOTICE, tests, verification utility, packaging scripts and prepared CI/Xcode UI-test targets.
- Fixed Safari discovery when macOS exposes its link as both hidden and alias-like; avoid interpreting missing usage as unused.

This version is not publicly released. Some providers are fixture-verified only or explicitly unsupported for particular layouts. Full Xcode/XCUITest, clean-machine and minimum-OS runtime verification remain pending.

### Resumed QA pass
- Single-app uninstall preview, confirmation, source-specific handoffs and injected simulation; no real removal tested.
- Modern Toolbox generated-launcher association and macOS 14+ native column controls.
- Corrected hidden-row details, vendor metadata provenance and column refresh behavior.
- Actual GUI captures and expanded inventory/size/date audit.

### Official branding and native UI refinement
- Integrated owner-supplied icon artwork in all macOS icon sizes, native toolbar and About; official README lockup and asset provenance.
- All six native table headers sort with direction indicators, ascending on field change, missing values last and deterministic identity ties. Numeric version comparison and stable selection retained.
- Native hover help/accessibility hints across controls, full truncated value help, wider Source column and clear shown/total/system-hidden status.
-67 tests pass including 5 new sorting tests; no destructive uninstall tests.

### Settings and About polish
- Fixed sidebar utility footer; top-aligned, scrollable native settings pages with consistent label/help/control rows.
- Editable bounded Recently Installed/Possibly Unused day fields and steppers; clearer scanning, discovery, diagnostics and cache explanations.
- Branded About window with exact owner-supplied LinkedIn/GitHub profile links and explicit unavailable project-repository state.
- Alpha-aware toolbar-only artwork; original branding and Finder/Dock icon preserved.
-70 tests pass, including 3 settings/link tests; live destructive removal remains untested and prohibited in QA.

### Final product and publication preparation
- Transactional Settings: validate/save on Done; Cancel or window closure discards edits. Discovery-location/system-root changes request at most one rescan; appearance and threshold edits do not.
- Information page replaces Advanced; official repository joins native About profile links. Toolbar mark has no shared capsule background on supported macOS.
- Isolated, non-actionable 13-record demo dataset and four actual native public screenshots. Real cache/preferences remain unchanged.
- Seven additional transaction/demo tests; total 77 tests in 11 suites. XCUITest updates prepared; full Xcode remains unavailable.
- Professional README, publication audit/manifest tooling, preserved Apache LICENSE/history, reviewed ignore rules and owner-approval Git integration plan.
