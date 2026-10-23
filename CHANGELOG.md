# Changelog

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
