# Cloud Xcode verification — 24 October 2026

Macventory 1.0.0/build 102. These changes are prepared locally; no revised GitHub run has executed. No commit, push, tag, release or repository-setting change is authorized by this work.

## Failure evidence and fix

[Original run](https://github.com/vadimtanel/MacVentory/actions/runs/40019617689), arm64 job 120640465787: macOS 15.7.9, Xcode 16.4/16F6, Swift 6.1.2. The package build fails at `InventoryView.swift:36`, reporting that the compiler cannot type-check `body` in reasonable time. Subsequent tests, Xcode build/tests and packaging were skipped. Both matrix jobs failed. The failed run checked out 1cc7ac49; this repair starts from the newer local a7d2a9c baseline containing standalone Trash support.

`body` previously placed the entire split view, nested source filtering/counting, sidebar controls, detail content, toolbar and presentation/lifecycle modifiers in one generic SwiftUI expression. The refactor creates separate opaque view properties for the sidebar, footer, content, split pane, status and toolbar; source filtering/counting and row rendering have their own typed boundaries. State stays in InventoryView; sorting, filters, table actions, settings, selection cleanup and uninstall sheet/revalidation behavior are preserved. No AnyView or type-check timeout increase is used.

This addresses the reported expression complexity. Separately, the source uses SDK 26 SwiftUI APIs such as sharedBackgroundVisibility: an availability check protects older runtimes but cannot provide declarations missing from the SDK 15 shipped with Xcode 16.4. A compatible build SDK is required. Local Swift 6.4 accepts both the old and refactored source; confirmation with the pinned cloud compiler is still pending. The old compiler's complete diagnostic set after decomposition is unavailable locally.

## Selected hosted environment

Both workflows use standard `macos-26` (arm64) with `DEVELOPER_DIR=/Applications/Xcode_26.5.app/Contents/Developer`. The [GitHub image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md) lists Xcode 26.0.1, 26.1.1, 26.2, 26.3, 26.4.1, 26.5 and default 26.6, with SDK 26.5 in 26.5/26.6 when inspected. [Apple's compatibility table](https://developer.apple.com/xcode/system-requirements/) lists Swift 6.3 and macOS SDK 26.5 for Xcode 26.5. The project uses Swift 6 language mode; matching local Swift 6.4 exactly is not required by its source syntax. Actual cloud compatibility remains to be demonstrated.

The verification script prints installed Xcodes, selected developer/compiler/SDK paths, architecture, macOS, Xcode, Swift and SDK versions. It rejects an unexpected architecture, OS major, Xcode, compiler minor or SDK rather than falling back to a changing default. If GitHub removes this preinstalled toolchain, update the pin deliberately. Nothing installs Xcode or authenticates to Apple. Intel was omitted; it is not a primary validation requirement.

The Swift helper honors DEVELOPER_DIR and invokes Swift through xcrun so SwiftPM and Xcode use the same selected installation. The existing local CLT/SDK 26.5 workaround is retained. Workflow shells explicitly enable bash's failure propagation through log pipelines.

## Checks prepared for GitHub

The primary job runs SwiftPM build, synthetic Swift Testing, Xcode app build, compilation of both Xcode test targets, isolated hosted unit tests, arm64 release packaging, and artifact validation. Unit tests use the shared scheme's explicit --ui-testing app-host argument; the project generator preserves it. Existing XCUITests explicitly launch with the same fixture argument. Live integrations are disabled in these workflows. No real removal executor is invoked by the tests.

A separate XCUITest job attempts the GUI suite after primary validation. It records the raw outcome, log and xcresult. An unsuccessful attempt produces a warning, explicit incomplete-verification summary, and failing UI job; it never turns a failed/skipped GUI attempt into a pass. Inspect the evidence before classifying a failure as a hosted GUI, accessibility or permission limitation. No hosted GUI limitation has yet been observed in the revised workflow. The primary arm64 job retains its independent result.

App/ZIP/DMG/source artifacts and SHA-256 checksums are workflow artifacts only, retained for 14 days. No GitHub Release or tag is created. Builds use ad-hoc signing (`-`), empty development team, no provisioning updates, no Developer ID, no notarization and no Apple credentials.

Validation checks native arm64 architecture, app signature, version/build plist values, DMG integrity, all checksum entries, ZIP integrity and every bundled file's bytes, and source archive membership/hashes against the reviewed publication manifest. It does not install or launch an app. DMG Finder layout and quarantined/clean-machine launch are separate historical/pending checks, not claimed by this script.

## Local results and limits

- Fresh SwiftPM debug build in a separate scratch directory passed using existing Swift 6.4 and SDK 26.5 (35.92 seconds).
- Swift Testing reported 91 tests in 12 suites passed; the 3 opt-in read-only live integrations were explicitly skipped. No live integrations were rerun in this repair.
- Optimized arm64 app and ZIP/DMG/source/checksum packaging passed. The sandbox prevented disk-image device access on the first attempt; packaging succeeded with the same script outside that sandbox.
- Artifact validation passed: 1.0.0/build102, arm64, signature, DMG integrity, checksums, matching ZIP files and exact source manifest.
- Workflow YAML parses; modified shell scripts pass syntax checks; project plist and scheme XML validate; regenerating the project changes only the intended test arguments. Git whitespace checks and publication path/pattern/link audit pass. These are static checks, not a GitHub Actions execution.
- Existing CLT warnings remain: native build-system deprecation and the Swift Testing framework's macOS 14 minimum versus a linked macOS 13 target. Tests actually run on the current OS; this does not establish macOS 13 support for tests. The Xcode unit-test target already requires macOS 14.

Local full Xcode build/unit tests/XCUITest were not attempted. There was no Xcode installation or Apple authentication. No real application/package was modified or removed; real settings/cache were not cleared. No new GUI verification is claimed for this refactor.

## Required next step

Review these uncommitted changes, then authorize a commit/push to a review branch. GitHub cannot execute local uncommitted workflow files; rerunning the old run would rebuild its old revision. After an approved push, inspect the new native and GUI job results and downloaded evidence, and repair any cloud-only issues before calling Xcode CI verified. Cloud compilation, Xcode unit tests and XCUITest are pending, not passing claims.
