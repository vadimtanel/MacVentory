# Continuous integration — v1.1.0

Current metadata: **1.1.0 / build 108**. Workflows are implemented and have hosted execution evidence; the historical repair report below describes an earlier build and must not be read as current branch, authorization or CI status.

## Completed release CI — 27 October 2026

The [release-commit run 40535995628](https://github.com/vadimtanel/MacVentory/actions/runs/40535995628) passed at tagged commit `54bb40270bf8309ce454cfb0cf73c80afed07ef9`. Both native and UI jobs succeeded: builds, unit tests, packaging/artifact validation, **17 primary GUI tests with zero failures**, count/order verification, xcresult export, header comparisons, independent pointer diagnostics and final reporting.

The [full stabilization run 40529352261](https://github.com/vadimtanel/MacVentory/actions/runs/40529352261) also passed **17/17, zero skipped**, and the [focused pair 40526878294](https://github.com/vadimtanel/MacVentory/actions/runs/40526878294) passed **2/2** at `ca618773dd333db2654c2d569ea782dc3a6e4784` on macOS 26.6.2. The native search-field correction resolved first-click selection and matching Details. PR #4 is merged and v1.1.0 is published. See [verification](VERIFICATION.md) for manual VM testing and distribution limits.

## Current workflow contract

[Build and test Macventory](../.github/workflows/ci.yml) runs on push, pull request and manual dispatch. Both jobs use standard `macos-26` arm64 and pin `DEVELOPER_DIR=/Applications/Xcode_26.5.app/Contents/Developer`. The toolchain script verifies actual architecture, OS, Xcode, Swift and SDK; a missing pin fails rather than silently selecting a default. Opt-in read-only live integrations are disabled (`MACVENTORY_LIVE_TESTS=0`). Signing is ad hoc with no Apple credentials/notarization.

| Job | Required work |
|---|---|
| `native` | SwiftPM build/fixture tests, Xcode app build, compilation of all test targets, isolated hosted Xcode unit tests, arm64 app/ZIP/DMG/source packaging, artifact validation and evidence upload |
| `ui` | Synthetic XCUITest, actual count/order/result verification, full-scenario native header comparison and independent pointer diagnostic, explicit outcome reporting and evidence upload |

App hosts use isolated `--ui-testing` data and simulation; no real removal or helper activation is part of CI. Production adapters with fake effects verify orchestration and error contracts, not real destructive correctness.

## Full runs versus diagnostic scenarios

The stabilization PR selects `isolated` on synchronization; other push/PR runs select `full`. Manual dispatch defaults to `isolated` and must explicitly select `full` for final release verification after focused Selection/Details succeeds. Available diagnostic scenarios are `startup`, `isolated`, `paths`, `after-layout` and `after-headers`; their successful subsets cannot validate the complete suite. `startup` executes only `MacventoryStartupDiagnostics/testAOriginalActivationAndSelectionDiagnostics`; the abandoned Gate A2 comparison remains archived, outside the workflow. [Startup verification passed](https://github.com/vadimtanel/MacVentory/actions/runs/40405018837) at `1fe3c150e2fba555c42d352d7986ee214dceae17`.

Pushes to `release/v1.1.0-stabilization` are excluded from the push trigger to avoid duplicating its PR run. Reuse that focused PR run instead of also dispatching the same candidate. Both jobs check out the exact PR head SHA; the GUI verifier checks that candidate SHA rather than GitHub's synthetic merge SHA. Full stabilization validation uses an explicit `full` dispatch. No workflow publishes or merges anything.

The stabilization suite retains all **16 original** primary `MacventoryUITests` methods plus `testSearchSelectionAndDetailsContract` (**17 total**). `isolated` requests the original failing execution-level case and the new selection-only regression; `full` requires all 17. `scripts/verify-ui-selection-run.py` checks actual starts/passes, missing/failed/skipped/repeated cases and exactly one successful Xcode terminal marker against an explicit coverage list, then verifies the source still contains that list. Inspect `selection-scenario.txt`, `tested-head.txt`, `gui-sequence.json`, raw exit status and xcresults for agreement with the requested SHA/scenario. Diagnostic-class methods are separate.

The primary GUI step has **no `continue-on-error`**. `scripts/run-ui-tests.sh` preserves the actual Xcode and log-writer exit codes and fails on missing/skipped/failed cases even if the process exits zero. Evidence, sequence verification, independent diagnostics and final reporting use `always()` where appropriate. Further desktop diagnostics run only after the primary Xcode execution finalized normally with a result bundle; interrupted attempts cannot authorize another desktop test. Final reporting also requires successful xcresult export and, for `full`, both header/pointer diagnostic steps. A native-only success does not establish full CI. The completed release runs above passed both jobs and all required gates.

The runner's Xcode supplies `xcresulttool`: the workflow exports primary summary, test tree, activities and attachments on finalized success **or failure**, alongside the intact xcresult. An individual export failure still attempts the remaining exports and fails the evidence step. QA-only selection traces additionally capture native changing/committed notifications and search-end-editing caller stacks; these observations do not identify a clearing writer unless a recorded mutation actually supports that conclusion. Missing Details is recorded as absent during failure capture, preserving the original assertion rather than producing a second geometry-query exception. Synthetic Python regressions validate process exit propagation, coverage, SHA/scenario/arm agreement, continued evidence collection and final failure reporting without starting Xcode/apps.

## Artifacts and publication boundary

`verification-arm64` includes verification logs, built app and versioned release candidates. `verification-ui` includes GUI evidence. Uploads are retained for 14 days. Artifact validation checks signatures, architecture, source/app version/build agreement, private compiler-path absence, DMG integrity, all SHA-256 entries, ZIP file bytes and exact reviewed source-manifest membership/hashes; it does not install or launch the app.

The manual [packaging workflow](../.github/workflows/package.yml) builds/tests/packages and validates artifacts but does not run the full Xcode/GUI sequence. It cannot replace the full workflow. Neither workflow creates a Git tag/GitHub Release or updates the separate Tap.

## Historical evidence for documentation preparation — 26 October 2026

**Superseded checkpoint.** The failures and proposed next steps below belong to earlier revisions. They do not describe the released v1.1.0 commit or current PR status.

The starting `main` SHA is `a5a66efcaf2f1b06c3f32bb104e6125239f831c9`. [Push run 40309598774](https://github.com/vadimtanel/MacVentory/actions/runs/40309598774), attempt 1, completed with **failure**. The native job (`121527167267`) passed, including hosted Xcode units, packaging and artifact validation. The UI job (`121529874468`) failed its actual-count/order verification and final outcome reporting. GitHub's step summaries list the primary XCUITest step and both header diagnostics as successful, but that does not override the failed sequence gate or establish all 16 cases passed. Raw logs/xcresults still require inspection to explain the mismatch; no underlying selection fix/failure is inferred from summaries alone. This is a dated observation, not a live status badge.

Subsequent evidence: the preserved documentation commit `3c99886e9fe2f625279e9fe75aab83dc9274e0c1` already exists on `release/v1.1.0-stabilization`. Its [push run 40316125739](https://github.com/vadimtanel/MacVentory/actions/runs/40316125739) also failed: 16 primary cases executed, 15 passed and the same execution-level case failed. Raw trace/controller/startup records were inspected in this stabilization review. The local patch has no hosted validation; after separate commit/push/dispatch approval, require focused success before one full run on the exact final SHA. See [the stabilization evidence and limits](STABILIZATION_SELECTION_REVIEW.md), [Verification](VERIFICATION.md) and [release sequence](RELEASING.md).

At this historical checkpoint, real provider effects, native Trash, signed-helper deployment, macOS 13 runtime, full VoiceOver and clean-machine Gatekeeper were outside the recorded checks. See the current [verification summary](VERIFICATION.md) for subsequent CI and maintainer-confirmed VM testing. Default ad-hoc signing is intentional; Developer ID/notarization are not supplied by these jobs.

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
