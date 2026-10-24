# Repository cleanup — Macventory 1.0.0 build 101

## Build 104 additions

This correction pass adds one visually reviewed public screenshot, `macventory-leftover-data.png`, using only synthetic QA group names with no candidate selected or private path visible. The publication screenshot allowlist explicitly includes it. Other QA copies, fixture bundles, runtime reports and private Dark Mode evidence remain under ignored build paths. No real application/user data/cache was cleaned. Existing staged source additions were preserved; this pass performed no index, history or remote changes. Original branding/license/NOTICE assets remain unchanged.

This pass changes repository hygiene and source packaging only. Application source, tests, approved artwork, icon derivatives and completed UI behavior are preserved. No real uninstall, installed-software modification, cache clearing, staging, commit or publication.

## Design audit and resource dependencies

| Retained input | Reason |
|---|---|
| Design/Branding/app-icon-source.png | Original owner artwork; input to make-icon.swift and make-toolbar-mark.swift. Original hash retained. |
| Design/Branding/brand-lockup-reference.png | Original owner lockup; README hero directly references it. Original hash retained. |
| Design/Branding/README.md | Asset provenance, hashes and regeneration instructions. |
| Resources/Macventory.icns | Approved compiled icon; Info.plist, bundling, Xcode resources, About and running-icon initialization depend on it. |
| Resources/ToolbarMark.png | Approved toolbar derivative; bundling/Xcode/shared brand loader depend on it. |
| Resources/DMG/background.png, FinderLayout, README.md | Native installer layout/background and its documented provenance; packaging dependencies. |

These are all Design files after cleanup. No original artwork was duplicated, redesigned or regenerated. Different-size iconset files were generated intermediates, not original sources. Three pairs also had identical bytes at equivalent pixel dimensions; all ten were unnecessary publication inputs because normal builds copy the existing ICNS. Regeneration remains possible from the original and retained script.

## Removed or archived

Deleted only three verified Finder metadata files: root .DS_Store, Design/.DS_Store and Sources/.DS_Store. Their Bud1 signatures identified ordinary folder metadata; no source/build/document dependency referenced them.

Moved Resources/Macventory.iconset/ (ten generated PNGs) into ignored build/cleanup-archive/Macventory.iconset/ for recovery. Added a root-scoped ignore rule so future regeneration stays local. No shipped icon changed.

Moved ten unreferenced root QA logs into ignored build/cleanup-archive/root-logs/: app-build-log.txt, audit-log.txt, build-log.txt, dmg-mount-log.txt, dmg-verify-log.txt, integration-log.txt, intel-build-log.txt, packaging-log.txt, test-log.txt and validation-log.txt. Public source/scripts/docs had no references to these paths. No evidence was destroyed.

## Other retained files

All Swift source belongs to the three SwiftPM targets or test target; Xcode/SwiftPM entry points remain. No source file or dead-code candidate was proven safe to remove. Tests generate synthetic fixtures; Fixtures/README.md explains their location/coverage.

Kept the build/toolchain/package wrappers, native asset generators, Xcode project generator, independent inventory validator and publication audit. Each has a distinct build/reproduction/verification purpose. CI verification and manually requested artifact packaging workflows are distinct.

Kept README/license/NOTICE/security/contribution/changelog, architecture/specification/source-support/release/verification docs, five official synthetic/installer screenshots and the recovery checkpoint. Technical plans remain useful project documentation, not disposable agent scratch. No agent scratch/config file was present in the proposed public set. Ambiguous ignored build evidence and compiler caches were left alone.

## Git and packaging hygiene

Existing rules exclude compiler/Xcode/SwiftPM output, build/artifacts, local logs/inventory/diagnostics, credential/environment files, editor state and Finder metadata. No tracked ignored file exists; LICENSE is the sole tracked file and remains unchanged. Positive checks retain original/shipped resources, source, tests, scripts, workflows and official screenshots.

Found a concrete source-package gap: recursive tar inputs could include regenerated ignored files under Resources or other public directories. Source packaging now uses the exact reviewed publication manifest, so ignored data cannot return through recursive archive traversal. The generated iconset is excluded even if recreated locally. No broad ignore rule hides Design or Resources.

The publication audit scans proposed text inputs for credential-shaped content, developer paths and broken local links; binary artwork/screenshots/Finder metadata receive separate review. It is not a guarantee against every possible secret. Exact paths/size/SHA-256 are in ignored build/publication-manifest.json and its text list. Git history/index/remotes are unchanged; approval is still required before staging/committing/pushing/tagging/publishing.

## Verification

83 tests in 11 suites passed with all three read-only live integration tests enabled. Approved completion/branding code and tests have identical before/after hashes. Rebuilt the app, ZIP and DMG successfully with Resources/Macventory.iconset absent. ZIP signature/resource checks passed. The cleaned source archive contains exactly 85 reviewed files and no generated iconset/private outputs; membership and SHA-256 comparison passed. Final source archive/checksums are refreshed after these report edits.

Small actual GUI smoke test used only the ZIP-extracted --demo app: 13 fictional rows, sidebar/table, visible toolbar mark and About 1.0.0 content rendered; then the instance was closed. No uninstall workflow or cache maintenance was exercised. Real cache/settings hashes matched before/after. No new product regression was discovered. Prior Xcode/XCUITest and direct visual Dock inspection limitations remain unchanged.

Publication pattern/local-link checks report zero findings. Seventeen representative ignore probes pass; all 85 proposed inputs remain visible and no tracked file is ignored. Python/shell syntax and Xcode project plist syntax pass. Current proposal is 84 additions plus existing unchanged LICENSE; nothing is staged. Original artwork and all required build resources remain intact. See CHECKPOINT.md and VERIFICATION.md for retained baseline verification.
