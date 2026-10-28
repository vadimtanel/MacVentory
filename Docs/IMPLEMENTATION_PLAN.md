# Macventory implementation plan — revised 2026-10-23

**Historical report.** v1.1.0 was released on 27 October 2026 with passing native/GUI CI. See [current verification](VERIFICATION.md) for completed checks and manual VM testing. Failed/pending checks, branch state and proposed next steps below apply only to the dated development pass.

SPEC.md remains the authoritative product specification. The owner's revised authorization replaces full Xcode as an immediate dependency with Swift Package Manager, the installed Swift compiler/macOS SDK, native SwiftUI/AppKit, and a small app-bundling script. Architecture and all ten source categories are preserved. No further Apple authentication or Xcode downloads will be attempted.

## Architecture
- Native SwiftUI application, shared MacventoryCore module, independently testable scanner implementations, and a development-only InventoryVerify executable.
- Swift Concurrency coordinator, bounded source and size jobs, evidence-aware physical-installation merging, conservative smart views.
- Versioned Codable snapshot in application-owned local storage; no backend, network, accounts, telemetry, manager mutation, or privileges.
- The installed macOS 27 SDK requires a SwiftUI macro plug-in absent from Command Line Tools. The build wrapper uses the installed macOS 26.5 SDK and native SwiftPM build system. This produces a native .app targeting macOS 13, not a CLI substitute.

## Milestones and gates
1. Foundation: compile native app and core; package valid .app; execute core/safety tests; verify launch and visible window.
2. Core inventory: native, App Store receipt evidence, Homebrew casks/formulae, PKG; sidebar/table/details/search/filters/sorting; compare real installed payloads and versions.
3. Additional providers: MacPorts, Nix, Setapp, Steam and Toolbox; fixture tests and explicit unsupported/experimental states; live verification only where installed.
4. Metadata and discovery: asynchronous logical size, usage/install evidence, conservative smart views, cache/cancellation/failure handling; test and measure.
5. Open source: README and supporting docs, Apache-2.0/NOTICE, native icon, CI definitions, local ZIP/DMG/checksums, honest verification report.

After each significant change, build and run relevant tests. Keep Docs/CHECKPOINT.md current. Fix reproducible failures before delivery. No commits, remote changes, pushes or publication are authorized.

## Deferred verification
- Xcode project build and XCUITests: **BLOCKED — Full Xcode unavailable**.
- Hosted GitHub Actions: prepared locally; not executed; pushing source/workflow and running hosted verification await owner approval.
- Intel hardware, macOS 13 runtime and clean-machine Gatekeeper installation require environments not currently available.
- Native GUI automation became available in the resumed pass. Record actual interaction evidence separately from launch-only and fixture checks.

## Final reporting
Separate IMPLEMENTED AND VERIFIED, IMPLEMENTED BUT NOT VERIFIED, BLOCKED BY XCODE, and NOT IMPLEMENTED. Do not call the app release-ready while mandatory verification is incomplete.

## Resumed QA and uninstall amendment

The previous run stopped after reading the real GUI accessibility tree; a row-selection action was interrupted before any QA source changes. Preserve the architecture and existing 49-test baseline.

1. Audit the real GUI/source counts, duplicate-looking paths and Spotlight availability outside the restricted CLI.
2. Add modern Toolbox inference using documented generated-launcher locations, explicit generator markers and exact existing IDE paths; never execute scripts.
3. Add native column customization on macOS 14+ with macOS 13 fallback.
4. Add an independent uninstall planner, fresh validator, confirmation session and injected executor. QA always uses simulation-only policy. No real installed software or user data may be changed during this run.
5. Add non-destructive tests; rebuild/rescan/audit/launch native and ZIP bundles; update reports and local artifacts. Xcode verification remains blocked. No commits/publication.
