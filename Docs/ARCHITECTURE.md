# Architecture — Macventory v1.1.0

Macventory is a native SwiftUI macOS app with shared MacventoryCore code. SwiftPM supplies the CLT-compatible build; the checked-in Xcode project uses the same sources and embeds MacventoryCore as a framework. The bundling script creates a self-contained app. Current metadata is **1.1.0 / build 108**.

## Components

- **Macventory:** main-actor observable app state; navigation/sidebar, inventory table, evidence/health details, management, Leftover Data, Settings and About. Search/filter/sort use cached in-memory results. Compact layouts keep actions accessible.
- **Domain:** installation records, source/field evidence, confidence/availability, source reports, configuration, installation health and deterministic sorting.
- **Scanning:** independent Sendable scanners and an InventoryService actor; at most three source tasks and two size tasks run concurrently. Results update progressively.
- **Infrastructure:** bounded filesystem/native/Spotlight access, typed command execution, versioned snapshots/identity records and sanitized diagnostics.
- **Removal:** immutable preparation, confirmation and fresh validation, with strategy-specific adapters and injected effect boundaries. Discovery never enters these effects.
- **MacventoryPrivilegedHelper:** narrow exact-request MacPorts helper bundled with identity/LaunchDaemon metadata. Discovery never registers it; ad-hoc builds cannot use the trusted privileged route.
- **InventoryVerify:** development-only read-only inventory verification/benchmark executable.

## Identity, health and source merging

Canonical physical paths identify installed payloads. Symlink discoveries collapse while separate copies/keg versions remain separate. Manager records map to native payloads; Steam directory records can own contained bundles. Display names/identifiers alone do not merge physical copies. Conflicting owners/profiles/prefixes become ambiguous.

InstallationHealth stores status, explanation, checked time, manager registration and expected-artifact observations. Absence, broken links and inaccessible paths differ. Missing Homebrew apps with installed tokens are attention cases; absent/unmapped PKG payloads can leave historical receipts. CLI-only packages need no GUI app. Cached/failed observations remain unverified. Health never grants removal authority.

## Scan lifecycle and persistence

Snapshots load stale, then optional refresh replaces each successfully scanned source. Failed/cancelled sources retain visibly stale observations without erasing unrelated successes. Generation guards reject superseded results. Logical size measurement runs off the main actor and retains incomplete/unknown footprints.

The atomically replaced Codable inventory snapshot uses schema 1, a 32 MiB bound and optional health fields compatible with earlier snapshots. Unsupported/corrupt data has an explicit refresh path. A separate bounded application-identity index (schema 1, 4,000 records, 4 MiB, two-year retention) retains names and recorded embedded-parent associations without installation paths/usage history. Snapshot name evidence migrates before refresh. Minimal confirmed-removal records are distinct from inventory and identity observations.

Names/parent relationships support presentation, never ownership. Leftover discovery correlates current inventory and Launch Services, keeps unknown/stale associations possible-only and preserves structured partial-scan issues. Default-off personal-folder suggestions are bounded direct-child scans, not recursive sweeps.

## Read-only discovery and explicit effects

Discovery uses bundle/manifest/receipt reads and typed bounded queries, including Homebrew installed state, pkgutil, MacPorts and Nix. It does not evaluate package recipes, authenticate accounts, execute provider frameworks or mutate manager state. Missing dates remain unknown; file creation is distinct from installation and Spotlight usage is incomplete.

Normal inventory needs no backend or network. Explicit official-documentation opening performs an ephemeral HTTPS HEAD request, validates same-provider redirects and then opens the browser; webpage text is never a command source. External managers/vendor tools can have their own effects/network behavior after confirmation. User-initiated diagnostic export contains counts/status, not inventory names/paths.

Application-owned cache/preferences/history and explicit exports are normal local writes. Separately confirmed management can request exact process termination, native recoverable Trash or the reviewed manager/vendor operation. Thus read-only discovery does not imply that every app action is read-only.

## Removal execution and authorization

UninstallPreparationService resolves one eligible strategy; UninstallLevels binds level/scope/evidence to an immutable plan. UninstallSession/ManagementSession consume single-use acknowledgment and repeat fresh identity/ownership/process checks. UninstallExecutionService dispatches exactly the confirmed strategy through Homebrew, managed MacPorts/Nix, native bundle, embedded vendor or Steam adapters. Failures never fall back to a different removal mechanism.

Interactive launch returns Waiting for User; independent verification preserves previous combined-step results. Manager exit zero alone is insufficient. Bundle-only removal verifies original-path absence, not every external component. App-data and Leftover Data actions have separate exact-path confirmation. Timeouts/cancellation do not guarantee rollback.

MacPortsAuthorization and the helper validate exact version/prefix/payload fingerprints, both XPC peer identities and per-request OS administrator rights before preflight and the final effect. Trusted matching signing and explicit OS helper approval are required; pending approval queues nothing. The released ad-hoc build cannot enable this privileged route; separate signed deployment/lifecycle verification is outside the automated fixture suite.

## Compatibility and evidence

App/helper deployment is macOS 13.0; test hosts require macOS 14+ for Swift Testing. arm64 is primary. Intel, minimum-OS runtime and clean-machine Gatekeeper need separate evidence. Full Xcode validates project/framework/test integration beyond SwiftPM.

See [current removal matrix](UNINSTALL.md), [discovery matrix](SOURCE_SUPPORT.md), [CI](CI.md) and [verification](VERIFICATION.md). v1.1.0 is published with successful native/GUI CI, packaging/artifact validation and maintainer-confirmed manual macOS VM testing. Historical execution/audit reports preserve earlier snapshots. Synthetic effects and read-only inspection have narrower scope than real runtime testing; the [verification record](VERIFICATION.md) distinguishes those results and the shipped signing restrictions.
