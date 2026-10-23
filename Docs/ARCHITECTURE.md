# Architecture

Macventory is a SwiftUI macOS application with a small shared Swift module. The Swift package is the primary CLT-compatible build. The checked-in Xcode project references the same sources; it embeds MacventoryCore as a framework. SwiftPM links the core into its executable and the bundling script creates the ordinary .app.

## Components

- **Macventory:** main-actor observable app state; NavigationSplitView, Table, evidence-aware details, settings and About. Search/filter/sort operate on cached in-memory results.
- **MacventoryCore domain:** software installation records, source/field evidence, confidence, availability, source reports, configuration, conservative filtering and deterministic sorting.
- **Scanning:** independent Sendable SoftwareScanner implementations and an InventoryService actor. At most three source tasks and two size tasks run together. Async results update UI progressively.
- **Infrastructure:** bounded filesystem access, native bundle/Spotlight reads, typed read-only ProcessRunner, versioned SnapshotStore and sanitized diagnostics.
- **InventoryVerify:** development-only real-machine verification executable; not part of normal app operation.

## Identity and merging

Canonical physical paths are primary identities. Symlink discoveries collapse; separate paths and installed keg versions stay separate. Manager records map onto existing native payloads rather than creating an extra app row. Steam directory records can own contained game bundles. Display names never establish identity.

Ownership, store origin and installer mechanism are distinct evidence. Manager ownership takes priority over generic filesystem discovery; conflicting verified owners become ambiguous. Installer receipts coexist with manager evidence. A failed ownership scan leaves affected classification uncertain. Every discovered source remains available in details.

## Scan lifecycle

Load and mark the local snapshot stale, then optionally refresh. Each successful source replaces its prior observations. Failures/cancellation retain previous observations visibly stale and preserve successful unrelated results. A generation identifier prevents superseded scans from overwriting current UI state. Size enrichment runs off the main actor and never treats incomplete bytes as a complete footprint.

The cache is a single atomically replaced Codable document with schemaVersion=1, per-source observations, merged items and source reports. Unsupported/corrupt data produces an explicit message and can be rebuilt by refresh. A 32 MiB bound prevents unbounded growth. No historical usage database or daemon is present.

## Evidence and safety

Nil means missing, never zero or epoch. Installed dates come from a manager/receipt event; creation/modification dates are separate. Spotlight is an incomplete usage observation. All source records and important fields carry evidence and confidence. Possibly Unused requires credible old graphical-app usage and excludes system/CLI records.

Typed command cases allow only pkgutil/port/nix/nix-env inventory queries. Output is drained without blocking the main thread, bounded, and canceled/timed out. App operation does not invoke a shell, evaluate recipes, access credentials, run provider frameworks, or use the network. Local writes are limited to Macventory cache/preferences and explicit exports.

## Compatibility

Application deployment target is macOS 13; current Swift Testing tools require macOS 14+ for test execution. Intel compilation and older-OS runtime support must be verified separately. Full Xcode remains necessary for XCUITest and Xcode-project validation, but not for the primary native app build.

## Controlled uninstall boundary

UninstallPlanner produces an evidence-checked plan. UninstallSession consumes one plan-bound confirmation, FreshUninstallValidator rechecks it, and an injected UninstallExecuting adapter performs simulation or the reviewed production operation. AppModel selects simulation for both QA modes. Discovery scanners never invoke this path. See UNINSTALL.md for source-specific eligibility and pending destructive verification.
