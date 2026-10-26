# Continuous integration — v1.1.0

Current metadata: **1.1.0 / build 108**. Workflows are implemented and have hosted execution evidence; the historical repair report below describes an earlier build and must not be read as current branch, authorization or CI status.

## Current workflow contract

[Build and test Macventory](../.github/workflows/ci.yml) runs on push, pull request and manual dispatch. Both jobs use standard `macos-26` arm64 and pin `DEVELOPER_DIR=/Applications/Xcode_26.5.app/Contents/Developer`. The toolchain script verifies actual architecture, OS, Xcode, Swift and SDK; a missing pin fails rather than silently selecting a default. Opt-in read-only live integrations are disabled (`MACVENTORY_LIVE_TESTS=0`). Signing is ad hoc with no Apple credentials/notarization.

| Job | Required work |
|---|---|
| `native` | SwiftPM build/fixture tests, Xcode app build, compilation of all test targets, isolated hosted Xcode unit tests, arm64 app/ZIP/DMG/source packaging, artifact validation and evidence upload |
| `ui` | Synthetic XCUITest, actual count/order/result verification, full-scenario native header comparison and independent pointer diagnostic, explicit outcome reporting and evidence upload |

App hosts use isolated `--ui-testing` data and simulation; no real removal or helper activation is part of CI. Production adapters with fake effects verify orchestration and error contracts, not real destructive correctness.

## Full runs versus diagnostic scenarios

Push/PR select `full`. Manual dispatch defaults to `isolated`, so it must explicitly select `full` for final release verification. Available diagnostic scenarios are `isolated`, `paths`, `after-layout` and `after-headers`; their successful subsets cannot validate the complete suite.

The full scenario requires all **16** primary `MacventoryUITests` methods. `scripts/verify-ui-selection-run.py` checks actual starts, passes, missing/failed/skipped/repeated cases and the Xcode success marker against the source suite. Inspect `selection-scenario.txt`, `tested-head.txt`, `gui-sequence.json`, logs and xcresults for agreement with the run's SHA. Diagnostic-class methods are separate from the 16-case primary suite.

The GUI command has `continue-on-error` to preserve evidence collection. Sequence verification and final reporting still fail the job if execution did not validate. Further desktop diagnostics run only after the primary Xcode execution finalized normally; a cancelled/incomplete attempt is not a pass. A native-only success does not establish full CI.

## Artifacts and publication boundary

`verification-arm64` includes verification logs, built app and versioned release candidates. `verification-ui` includes GUI evidence. Uploads are retained for 14 days. Artifact validation checks signatures, architecture, source/app version/build agreement, private compiler-path absence, DMG integrity, all SHA-256 entries, ZIP file bytes and exact reviewed source-manifest membership/hashes; it does not install or launch the app.

The manual [packaging workflow](../.github/workflows/package.yml) builds/tests/packages and validates artifacts but does not run the full Xcode/GUI sequence. It cannot replace the full workflow. Neither workflow creates a Git tag/GitHub Release or updates the separate Tap.

## Evidence for documentation preparation — 26 October 2026

The starting `main` SHA is `a5a66efcaf2f1b06c3f32bb104e6125239f831c9`. [Push run 40309598774](https://github.com/vadimtanel/MacVentory/actions/runs/40309598774), attempt 1, completed with **failure**. The native job (`121527167267`) passed, including hosted Xcode units, packaging and artifact validation. The UI job (`121529874468`) failed its actual-count/order verification and final outcome reporting. GitHub's step summaries list the primary XCUITest step and both header diagnostics as successful, but that does not override the failed sequence gate or establish all 16 cases passed. Raw logs/xcresults still require inspection to explain the mismatch; no underlying selection fix/failure is inferred from summaries alone. This is a dated observation, not a live status badge.

The subsequent documentation commit changes source-archive inputs and has **no hosted validation yet**. After separate push approval, require full native/UI success and reviewed artifacts for its exact SHA before tagging. Older successful jobs do not validate new source/docs. See [Verification](VERIFICATION.md) and [release sequence](RELEASING.md).

Real provider effects, native Trash, signed-helper deployment, macOS 13 runtime, full VoiceOver and clean-machine Gatekeeper remain separate unverified areas. Default ad-hoc signing is intentional; Developer ID/notarization are not supplied by these jobs.

## Historical cloud Xcode repair report — 24 October 2026

The following build-102 report is retained unchanged as historical evidence. Its local/uncommitted and no-hosted-run statements refer to that repair pass only.

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
