# Macventory — Product Requirements & Technical Specification

**Version:** 1.6 — Macventory 1.1.0 uninstall and installation health

**Platform:** macOS Desktop  
**Original creator:** Vadim Tanel  
**Copyright:** © 2026 Vadim Tanel  
**License:** Apache License 2.0 with NOTICE  
**Technology:** Swift, SwiftUI  
**Distribution:** GitHub source, GitHub Releases, optional Homebrew Tap  
**Business model:** Free, open source, no advertising  
**Primary language of application UI:** English

> This document is the authoritative product specification. Application name: **Macventory**. Codex should review technical feasibility and document any necessary corrections rather than silently omitting requirements.

Current source metadata is **1.1.0 / build 108**; this release is upcoming, not published. Section 29 states the current implemented scope and supersedes conflicting earlier uninstall/privilege/UI limits. Build-specific sections retain their historical identifiers and are not evidence of final-release validation. See [verification](Docs/VERIFICATION.md).

## 1. Product Vision

Macventory is a native, local-first macOS desktop application that inventories installed applications, command-line tools, and managed software packages across different installation sources. It helps users answer:

- What is installed on my Mac?
- Where did each item come from (App Store, Homebrew, etc.)?
- Which version is installed, and where does it reside on disk?
- How much space does it occupy?
- When was it installed or updated, if that can be reliably determined?
- When was an application last opened, if that data exists?
- Which applications might be unused or taking up substantial storage?
- Are there duplicate discoveries or multiple physical installations?

**Core rule: never invent missing data.** Represent unknown, unsupported, inaccessible, inferred, and verified metadata distinctly.

## 2. Goals and Non-Goals

### Goals

1. Unified, searchable software inventory.
2. Left sidebar organized by install sources, plus smart views.
3. Responsive native Mac UI: list, search, filters, sorting, details.
4. Trustworthy metadata with confidence and provenance.
5. Identify potentially unused and large applications *without deleting them*.
6. Support Intel and Apple Silicon when feasible.
7. Operate locally without a server, login, telemetry or required internet.
8. Be easy to build from source, test, and share publicly on GitHub.

### Non-goals for v1

- Bulk uninstall, automatic removal, dependency cleanup, and automatic user-data removal.
- Automatic installation, package upgrades or updates.
- Always-on inventory/activity monitoring. The optional, explicitly approved MacPorts authorization helper is separate from discovery; see section 29.
- Tracking usage duration.
- Cloud sync, user accounts, backend or analytics.
- Broad system cleaning or guaranteed reclaimable-space calculations. Separately confirmed bounded app-data/Leftover Data review is permitted; automatic cleanup is not.

## 3. Technology and Architecture

| Concern | Choice |
|---|---|
| Language | Swift |
| UI | SwiftUI, AppKit only where necessary |
| Native APIs | Foundation, CoreServices/Spotlight, LaunchServices or supported equivalents |
| Concurrency | Swift Concurrency |
| Persistence | Local SQLite or an equivalently lightweight native store, justify choice |
| Unit/integration tests | Swift Testing / XCTest |
| UI tests | XCUITest |
| Build | SwiftPM/CLT native app bundling; Xcode/xcodebuild for project and UI validation |
| CI | GitHub Actions (macOS runner) |

**Minimum configured OS:** macOS 13.0, subject to runtime verification. Apple Silicon arm64 is primary; Intel compatibility is optional and not runtime-verified. The final executable must be an ordinary `.app` and not require Java, Node, Python, Homebrew, or command-line interaction for everyday use.

Architecture components:

- **Presentation:** SwiftUI navigation sidebar, software table, details, preferences, state and errors.
- **Application services:** scan coordinator, inventory merge, filters, sorting, metadata enrichment, unused-candidate evaluation.
- **Domain:** `SoftwareItem`, `InstallSource`, `SoftwareKind`, `MetadataEvidence`, `ScanStatus`, scanner protocol.
- **Infrastructure:** filesystem/native app discovery, package-manager scanners, metadata access, process runner, persistence.

Keep components separate but avoid excessive layers, frameworks or microservices. Scanner implementations must be independently testable.

## 4. Install Sources

Sidebar must support these **ten categories**:

1. **Mac App Store** — applications installed via Apple's store, when reliable local evidence exists.
2. **Homebrew Casks** — applications managed by Homebrew Cask.
3. **Homebrew Formulae** — command-line tools, libraries and formula installations.
4. **Direct / Unmanaged** — applications with no verified package manager or store source. Do not assume exact DMG/ZIP provenance.
5. **PKG Installers** — installation receipts and package-managed footprints.
6. **MacPorts** — MacPorts packages.
7. **Nix** — Nix profiles/packages as feasible through documented interfaces.
8. **Setapp** — Setapp-managed applications where verifiable.
9. **Steam** — games/applications via Steam manifests/libraries.
10. **JetBrains Toolbox** — Toolbox-managed IDE installations.

Additionally offer an **Unknown / Ambiguous** bucket. An item may have several detected sources, but one primary source when evidence supports it. Categories can overlap: PKG is an installer mechanism, not always mutually exclusive with a package manager. `All Software` must avoid duplicate records for one physical installation.

### Scanner contracts

Each scanner must:

- Detect whether its source is installed or available.
- Run read-only with no privileges beyond normal user access.
- Collect structured records plus provenance and confidence.
- Allow cancellation and bounded concurrency.
- Handle missing executable, malformed output, permission failure, timeout and empty result.
- Report errors without crashing or blocking unrelated scanners.
- Support fixtures/mocks for tests.

A source status must distinguish **Not Installed**, **Installed / Empty**, **Scanning**, **Completed**, **Unavailable/Unsupported**, and **Scan Failed**.

### Native application discovery

Discover `.app` bundles from `/Applications`, `~/Applications`, appropriate system application directories (optionally displayed), and configured additional directories. Use filesystem and available metadata discovery where appropriate. Avoid indiscriminate whole-disk recursion; handle aliases and symbolic links safely.

### Homebrew

Detect normal Intel and Apple Silicon installations and allow an optional custom path. Prefer documented machine-readable output (e.g., Homebrew JSON) and distinguish casks, formulae, linked/unlinked/keg-only state and multiple installed versions where relevant. Do not present a cask-owned `.app` as a second unrelated app.

### App Store

Use credible local store-origin evidence; absence of proof is not proof of App Store origin. If evidence is missing, report unknown/unmanaged. No requirement to access the user's Apple Account.

### PKG

Use package receipts and documented tools/APIs. A receipt alone does not prove the application payload still exists. Avoid treating every system receipt as a standalone application.

### MacPorts / Nix

Use documented installed-package interfaces, with careful environment/path detection, timeouts and tolerant parsing. Clearly mark unsupported configurations.

### Setapp / Steam / JetBrains Toolbox

Use documented or stable local manifests and installation locations when available, rather than guessing solely from app names. Verify each scanner with representative fixtures and, where possible, a real installation; label unverified support explicitly.

### Future extension points

Potential subsequent providers: npm global, pipx, Cargo, Conda, mise, SDKMAN, Adobe Creative Cloud, Epic Games. **Not required in v1.**

## 5. User Interface

Build107 sidebar selection supports a union of multiple library/smart/source categories via native Command-click. Apply ordinary filters/search to that union and retain unique physical-installation rows. All Software resets selection; Leftover Data is an exclusive destination. Cleanup permission diagnostics identify preflight versus Finder failure; folder review explicitly names whole-folder scope. Personal discovery remains opt-in and manual-only.

Use native `NavigationSplitView` with a persistent **left sidebar**, main software table, and optional details pane. The sidebar must not be replaced by a top row of source buttons.

### Sidebar

**LIBRARY**
- All Software
- Applications
- CLI & Packages

**SMART VIEWS**
- Possibly Unused
- Large Applications
- Recently Installed
- Unknown Metadata
- Attention Required

**INSTALL SOURCES**
- Mac App Store
- Homebrew Casks
- Homebrew Formulae
- Direct / Unmanaged
- PKG Installers
- MacPorts
- Nix
- Setapp
- Steam
- JetBrains Toolbox
- Unknown / Ambiguous

**OTHER**
- Leftover Data (separate review destination)
- Settings
- About

Show relevant item counts and scanner status. Allow hiding sources not installed on the Mac. A true zero count is different from scanner failure.

### Main table

Default columns: **Icon, Name, Version, Source, Status, Size, Installed, Last Opened**. Seven metadata/status headers sort; Icon is not a sort field. Native column customization is available on macOS 14+, with a fixed-column macOS 13 fallback. Drag-reorder/runtime coverage remains subject to verification. Default to table, not icon grid.

Search local cached results by name, bundle ID, package ID, source, path and version. Case-insensitive substring matching; do not rescan for every keypress.

Filters: source, software kind, minimum size, installation date, last-opened range, missing metadata, system vs third-party, and evidence confidence. Combine filters.

### Details panel

Show, where available:

- Icon, display name, developer/vendor.
- Bundle ID / package ID, version, kind.
- Primary and other detected sources, confidence and evidence.
- Canonical installation path.
- Installed date, updated date or separate file-created date.
- Size and metric description (logical vs allocated).
- Last opened and exact source of this value.
- Scanner state and last refreshed date.

Actions: **Reveal in Finder**, **Copy Path**, **Copy Identifier**, **Refresh Metadata**, and **Uninstall…** with the controlled workflow in section 22.

Empty/error/loading states should be clear, native and accessible. Support light/dark appearance and keyboard navigation.

## 6. Data Model and Provenance

`SoftwareItem` fields (optional where appropriate):

| Field | Type / meaning |
|---|---|
| `id` | Stable identity for installation record |
| `name` | Display name |
| `version` | Optional string |
| `bundleId` | Optional string |
| `packageId` | Optional string |
| `kind` | App, CLI, package, game, other |
| `primarySource` | Verified/inferred/unknown source |
| `detectedSources` | Source evidence collection |
| `installPath` | Optional canonical file URL |
| `sizeBytes` | Optional integer |
| `sizeMeasurementType` | Logical/allocated/other |
| `installedAt` | Optional verified installation date |
| `updatedAt` | Optional date |
| `lastOpenedAt` | Optional date |
| `isSystemItem` | Bool |
| `metadataEvidence` | Field-level provenance, confidence and error/availability |
| `scannedAt` | Date |

**Provenance** can include Homebrew JSON, bundle Info.plist, Spotlight, installer receipt, filesystem stat and package-manager manifest. Confidence categories: **Verified, Inferred, Unknown**; do not imply that an inferred value is verified.

Unknown metadata must not be replaced with bogus dates or zeros. Use distinct states for `Not Available`, `Unknown`, `Calculating`, `Access Denied`, `Scan Failed` and `Cached/Stale` where relevant.

## 7. Matching, Deduplication and Source Classification

One physical installation found by native app scan and Homebrew Cask is generally one row in All Software. Derive identity using **canonical path, bundle ID, package identity, resolved symlinks and independent evidence**, never only the display name. Two separate installed copies of the same bundle ID at different paths should normally remain separate. Preserve all source evidence, even when a single primary source is displayed.

Where ownership evidence is contradictory, show an **Ambiguous Source** rather than an invented resolution. Ensure idempotent repeated scans.

## 8. Installation and Last-Opened Dates

An installer receipt or manager-specific installation record may yield an actual date. Filesystem creation/modification date is **not automatically the installation date**. If only a file date is known, label it `File Created` or `Modified`, not `Installed`.

On macOS, Spotlight metadata such as `kMDItemLastUsedDate` may be available for some launched apps, but this is not a universal/fully reliable measure of user activity. Show it only when returned, with appropriate context. Lack of a value does not mean the item was never used. For CLI commands, generally show **Not Available** unless there is credible source-specific usage evidence. No activity-tracking daemon in v1.

## 9. Storage Size

Compute app bundle or package footprint when feasible. Distinguish **logical size** from on-disk allocated size; label the chosen metric. Handle permissions and symbolic links safely. Do not count the same physical files twice in aggregates. Do not silently include caches, shared dependencies or user data in an app's stated size. A package's size is **not** a guarantee of recoverable space. Calculate larger sizes asynchronously and show `Calculating…` while pending.

## 10. Smart Views

### Possibly Unused

User-selectable thresholds: **90, 180, 365 days**. Include only third-party graphical apps with credible last-opened data and a date beyond the selected threshold. Do **not** classify missing usage data as unused. Exclude system components, libraries and CLI dependencies by default. Explain why the item appears. No deletion.

### Large Applications

Sortable by size, with configurable threshold; missing size must be displayed as unknown, not zero.

### Recently Installed

Use only true verified installation dates for this grouping; optionally show separate `Recently Modified` view later.

### Unknown Metadata

Expose records lacking source, date, size or last-opened data to improve transparency.

### Attention Required

Expose actionable installation mismatches/partial states using stored source-aware health. Distinguish manager registration from expected-payload presence and historical receipts. A healthy CLI-only package need not have an app. Missing/access-denied/stale observations are not interchangeable, and a warning never grants removal authority.

## 11. Scanning and Cache Workflow

- First launch opens UI promptly and begins optional initial scan.
- Detect available sources; run supported scanner jobs concurrently with limits.
- Merge discoveries, enrich metadata and compute sizes progressively.
- Present partial results with visible progress and per-source statuses.
- Persist inventory locally for subsequent launch; mark cached data as cached/stale until refreshed.
- Manual **Refresh** initiates a new scan; `Cancel` stops relevant operations cleanly.
- Individual scanner failure cannot invalidate unrelated results.
- Re-running a scan must not create duplicate records.
- No always-on background process.

## 12. Settings

**General:** show system applications, hide unavailable sources, default sorting, system/light/dark theme.  
**Scanning:** custom app directories, external drive discovery off by default, scan on launch, cache controls.  
**Discovery:** bounded recent/unused-day thresholds and large-app threshold.

**Information:** scanner status, cache scope/maintenance and sanitized diagnostics.

**Optional personal discovery:** default-off bounded direct-child suggestions in Documents/Downloads/Desktop; possible-only, individual manual review and separate confirmation.

Do not display settings for features not implemented.

## 13. Security and Privacy

- Discovery remains read-only. A separate, explicitly confirmed single-app uninstall workflow may perform only its reviewed source-specific operation. Never upgrade packages, clean dependencies, remove user data automatically, or change system settings.
- Do not call `sudo` or request Full Disk Access as default.
- External commands must use fixed, validated executable paths and argument arrays, **not shell interpolation of user input**.
- Bound execution time, output size, process count and filesystem traversal depth where practical.
- Validate file paths and resolve symbolic links to avoid unexpected recursion.
- Handle permission failures gracefully.
- No telemetry, tracking, advertising, external server, account or data uploads.
- Local persistence only; users may clear local cache.
- No circumvention of Gatekeeper or platform security.

## 14. Performance and Reliability Targets

These are initial targets to **measure** rather than guarantees:

- Initial window visible in ~2 seconds on a reasonable test Mac.
- Interactive filtering of hundreds of entries without perceptible lag.
- Scan hundreds of metadata records in tens of seconds on a typical SSD, excluding potentially slow size enrichment.
- Progressive background size calculation; never block main UI thread.
- Low idle CPU; bounded memory and cache growth.
- Recover gracefully from malformed data, missing managers and canceled scans.

Document actual observed timings and test hardware.

## 15. Testing

**Unit tests:** normalization, matching, duplicates, source precedence, evidence handling, unknown dates, sorting/filtering, smart views, cache migrations, size labeling.

**Scanner fixture tests:** missing manager, installed-but-empty, valid/partial/malformed output, command timeout, permission denied, multiple versions, renamed app, paths with spaces and Unicode, symlinks, bundle/manager duplication.

**Integration:** real Mac scanning, compare returned items to known installed software; validate Homebrew casks/formulae and native applications first. For uninstalled managers, use fixtures but document lack of live verification.

**UI tests:** startup, sidebar navigation, search, filters, table selection, details, refresh/cancel, empty/error states, keyboard use, accessibility, appearance settings.

**Safety tests:** scanner commands never perform uninstall, update, mutation or privileged writes; cache only writes to application-owned local locations. Uninstall tests must use injected mocks/simulation exclusively; no test may remove real installed software.

## 16. Repository Layout

Suggested layout (adapt to actual size):

```text
Macventory/
  Macventory.xcodeproj
  App/
  Features/Inventory/
  Features/Details/
  Features/Settings/
  Domain/
  Services/Scanning/
  Services/Scanners/
  Services/Metadata/
  Services/Storage/
  Infrastructure/
  Tests/
  UITests/
  Fixtures/
  Docs/
  .github/workflows/
  README.md
  LICENSE
  NOTICE
  CONTRIBUTING.md
  SECURITY.md
  CHANGELOG.md
  SPEC.md
```

## 17. Branding, Licensing and Attribution

**Application name:** Macventory  
**Suggested tagline:** Know what's on your Mac.  
**Original creator:** Vadim Tanel  
**Copyright:** Copyright © 2026 Vadim Tanel

**Recommended legal route:** Apache-2.0 with the unmodified official license text and a `NOTICE` identifying the original creator. Display credit in the README and About window, along with the repository URL.

**Important legal distinction:** Apache-2.0 requires preservation of specified license, copyright and NOTICE information under its terms, but **does not generally require every derivative app to display the creator's name in its UI**. If mandatory *visible in-app attribution by all forks* is a hard requirement, reconsider licensing with legal review before publishing. Do not invent extra legal obligations while labeling the project Apache-2.0. The project name and trademark rights, if any, are separate issues.

About window:

> Macventory  
> Created by Vadim Tanel  
> Free & Open Source Software  
> Licensed under Apache License 2.0  
> [Official repository](https://github.com/vadimtanel/MacVentory)

## 18. Distribution Without Paid Apple Developer Membership

- Xcode development and local use must work without paid membership.
- Public GitHub repository with build instructions, screenshots, privacy statement and supported-source matrix.
- CI on GitHub Actions: builds and tests on supported macOS runners.
- Versioned GitHub Releases with source, ZIP/DMG app artifact if feasible, SHA-256 checksums, release notes and honest limitations.
- **Unsigned/unnotarized builds may trigger macOS Gatekeeper warnings**. Do not promise frictionless installation or suggest bypassing security protections as a routine installer step.
- Optional custom Homebrew Tap, after testing actual installation. A Tap does not make an unsigned binary notarized; admission to official Homebrew repositories is separate and subject to their policies.
- No GitHub push, public repo creation or public release without owner's explicit approval.

## 19. Implementation Phases and Gates

### Phase 0 — Foundation

Create project, compile SwiftUI shell, define domain/scanner contracts, safe process runner, cache and CI/test foundation.

**Exit:** app launches; build and initial tests pass.

### Phase 1 — Core Inventory

Native applications, Homebrew casks/formulae, Mac App Store evidence, PKG receipts and direct/unmanaged classification. Implement sidebar, table, details, search, filtering, sorting, progress, source statuses and basic deduplication.

**Exit:** demonstrably useful on a real Mac; report observed data accuracy and limitations.

### Phase 2 — Additional Sources

MacPorts, Nix, Setapp, Steam, JetBrains Toolbox via the common scanner contract. Add fixtures and actual-system verification when feasible.

**Exit:** all ten categories are represented, but distinguish implemented/verified from experimental or unsupported rather than falsely claiming full provider coverage.

### Phase 3 — Cleanup Discovery

Asynchronous size enrichment, Possibly Unused, Large Applications, Recently Installed and Unknown Metadata views. Evidence-aware rule explanations.

**Exit:** actionable read-only exploration without implying safe uninstall or inventing usage.

### Phase 4 — Public Release Preparation

Polish UI, accessibility, performance measurement, full test run, README/NOTICE/LICENSE, CI, packaging and clean-machine installation validation.

**Exit:** reviewed public-release candidate, **not** automatic publication.

## 20. Definition of Done

- Native graphical Mac app that launches normally.
- Daily usage requires no Terminal.
- Functional installation-source sidebar.
- Accurate inventory of supported applications and packages.
- Provenance-aware version, source, path, size and date metadata.
- No false installed/last-opened dates.
- No incorrect duplicate rows for same physical install.
- Search, sorting, filters and details work.
- Large/possibly-unused views apply explicit, conservative rules.
- Source errors are isolated and visible.
- Read-only operation proven through tests.
- Build, unit/integration and applicable UI tests pass.
- Real macOS runtime verification documented.
- Unsupported provider states, source-confidence and missing data explained.
- Project builds from README instructions.
- About/README/NOTICE credit creator correctly.
- GitHub Actions and release artifacts prepared and tested.
- No public push/release without explicit owner approval.

## 21. Codex Execution Instructions

Treat this `SPEC.md` as the authoritative **product requirements** and the user's separate execution prompt as the **workflow instruction**.

1. Inspect the local Mac toolchain, permissions and repository state first.
2. Review the full specification and identify feasibility gaps; record proposed corrections explicitly.
3. Create a concrete phased architecture and test plan, then implement incrementally.
4. Prefer native APIs and documented package-manager interfaces.
5. Keep architecture modular but simple; no unnecessary heavy frameworks.
6. Test after every significant milestone, including actual app runtime where possible.
7. Never fabricate metadata or disguise missing information.
8. Keep scanner behavior non-destructive and unprivileged.
9. Keep a checkpoint for interruption recovery.
10. Do not push, publish, or create a public release without explicit owner approval.
11. Report what works, what was actually verified, unresolved defects, limitations and readiness.
12. Do not stop after planning unless a real blocker requires owner input.

**Engineering priority:** Correctness → Safety → Simplicity → User Experience → Performance → Extensibility.

## 22. Controlled Single-Application Uninstall — Authoritative Clarification

Macventory must offer Uninstall… independently of read-only discovery.

- Preview the exact application, version, path, verified source, operation and retained user data. Require the review checkbox and explicit confirmation bound to that exact plan; no name typing. No bulk action or automatic dependency removal.
- Block system/critical components, running apps, stale/changed targets, uncertain ownership and unsupported mechanisms. Handle permission failures without administrator privileges or bypasses.
- Use source-specific mechanisms only when safety is established. Single app-only Homebrew casks may be removed without zap, force, dependency removal or cleanup. Casks with scripts/packages/extra artifacts require external-manager handling.
- Bundle-only Trash is not a complete uninstall. Offer it only for an explicitly verified eligible standalone/store bundle; explain external components/user data remain. Inferred unmanaged ownership alone does not establish eligibility.
- Explain external workflows for Steam, Setapp, Toolbox, package managers and vendor uninstallers. A PKG receipt alone does not define an uninstall procedure.
- Revalidate target identity and ownership immediately before execution. Cancellation after an operation starts cannot promise rollback.
- During development and QA in this execution, NEVER uninstall, delete, remove or modify real installed software/packages/user data. Use injected mocks and simulated execution only, including GUI testing in a visible QA safety mode.
- Actual destructive uninstall verification remains explicitly unverified pending separately authorized controlled testing.


## 23. Approved native UI and branding refinement

- All six table headers sort through a shared native comparator. Newly selected headers start ascending; repeat clicks toggle the native indicator. Size/date comparisons use underlying values, versions compare numeric runs with deterministic fallback, localized name/source comparisons and installation-ID ties remain stable. Missing values stay last in either direction. Search, filters, category and selection identity are preserved.
- The official owner-supplied PNGs in Design/Branding remain unchanged. AppKit derives the complete macOS iconset and ICNS; compact native toolbar and About use the official icon, README uses the lockup. No substitute artwork or invented repository link.
- Use native hover help and accessibility hints across interactive controls. Explain shown/total/hidden-system counts, expose full truncated source/name/version/date values, and retain native layout/column behavior.
- All existing uninstall safety requirements remain authoritative: QA always injects simulation; no real application, package, dependency or user data may be removed or modified. Xcode-dependent verification remains blocked; no tool installation/authentication retry or publication is authorized.


## 24. Approved Settings/About polish

Settings and About occupy a fixed, spaced sidebar utility footer. Settings uses a fixed native segmented page selector above top-aligned, scrollable content, consistent label/explanation/control columns, editable bounded Recently Installed/Possibly Unused day fields with steppers, explicit large-size units, and plain-language scanning/diagnostic/cache explanations. Clearing cache is a product feature, but no cache or user-data removal is authorized in this QA pass.

About shows official artwork, current version, creator/copyright/Apache2 credit, and the exact owner-supplied LinkedIn and GitHub profile links. Profiles and the official project repository use separate, verified destinations. The toolbar uses a reproducible alpha-aware derivative, leaving original PNGs and Finder/Dock ICNS unchanged. Existing uninstall simulation-only QA restrictions remain mandatory.


## 25. Official repository, settings transactions and publication safety

The official repository is https://github.com/vadimtanel/MacVentory. Preserve its existing LICENSE commit and remote configuration; no commits, merges, pushes or releases without explicit approval. Apache2 stays unmodified; NOTICE carries creator/project attribution without new restrictions.

Settings edits a draft across General, Scanning, Discovery and Information (formerly Advanced). Done validates/commits/persists once and requests at most one necessary scan for changed discovery inputs. Cancel/window close discards pending changes. Display-only changes do not scan. Maintenance is separate and never exercised against real data during QA.

Apple Silicon M1–M5 is intended; only M4 runtime is verified. arm64 is the release binary. Intel compatibility may remain, but is optional and not a release gate. Minimum deployment and tested OS must be reported separately.

Public screenshots must be actual native-window captures from isolated fictional demo data. No real cache/preferences/scans, personal metadata, actual software targets or destructive executor are permitted in demo mode. Demo markers independently block uninstall planning. VoiceOver can be called verified only if enabled, navigated and documented; AX inspection alone is insufficient.


## 26. Macventory 1.0.0 product refinement (historical UX clarification)

Remove name typing. Eligible previews show icon/full name/version/source/path/operation/retained data, readable wrapping/scrolling, an initially unchecked review checkbox, Cancel and Uninstall. Confirmation is single-use and bound to the exact plan UUID; fresh validation, source/target/protection/running checks remain mandatory. Reset acknowledgment for new plans, serialize requests and never let preview activation execute removal.

Native row primary action: single-click selects/details; double-click or Return opens review, including blocked guidance for packages/protected/uncertain/demo items. Retain item-targeted context menus. Headers/empty areas do not activate removal. Demo remains incapable of destructive execution.

All Settings changes, including Appearance, apply only on Done. No visual preview. Cancel/Escape/window closure discard all drafts. Display-only changes never rescan; discovery-input changes batch into one refresh.

Version1.0.0/build100 comes from Resources/Info.plist. Primary arm64 DMG/ZIP are self-contained and installable by ordinary copy; use a two-icon visual DMG with an Applications link. Free/ad-hoc signing is intentional. Paid membership/Developer ID/notarization are not requirements; document supported user-initiated Gatekeeper exceptions without automation/protection bypasses. Preserve all prior read-only scanning and simulation-only QA restrictions. No commit/tag/push/release/settings change without owner approval.


## 26. Standalone bundle removal — build 102 clarification

Keep inferred Direct / Unmanaged attribution. Independently assess scoped **Move to Trash** eligibility for current-user-owned, non-linked bundles directly in standard Applications folders. Require complete fresh supported-manager/PKG ownership checks, valid local bundle identity, permissions, no protected/system/service components, stopped application, explicit plan-bound checkbox confirmation and immediate revalidation. Use native NSWorkspace recycle only; distinguish its action from **Homebrew Uninstall**. Never permanently delete, sweep user data/dependencies, request elevation or fall back to shell removal. App Store and ambiguous/unsupported targets retain guidance. Preserve final two-line successful completion and OK-only state. QA uses synthetic bundles and mock executors exclusively; real destructive verification is forbidden in this execution.

## 27. Advanced application management and leftover data — build 103

Build106 superseding rules: reconcile confirmed missing targets after cleanup and partial refresh; retain inconclusive/access-denied observations with explicit errors. Per-item outcomes distinguish moved, already absent, changed, permission denied, protected, failed, unknown and skipped. Already absent never counts as a Macventory deletion. Validate independent items separately after duplicate/nesting checks; combined-operation preflight remains in place. Unknown native outcomes stop subsequent submissions and cannot cause automatic retry.

Personal-folder discovery is a default-off Scanning setting. When enabled, inspect at most 500 direct children each in current-home Documents/Downloads/Desktop, at most 30 matching folder measurements, 500 entries per size measurement and a five-second budget. Respect cancellation and permissions; report skipped/denied/linked roots. Use retained application names or exact identifiers for possible associations, never cleanup authority. Suggestions require manual selection and explicit exact-path review. Ambiguous/shared/unsafe/symlink targets are protected; no automatic selection or elevation. The default-off setting decodes safely from previous configuration formats.

A folder name of at least four characters may also suggest an uncertain association with a prefix of an identifier's final component (at most 16 remaining characters). Exclude broad generic folder names; multiple matching identities produce a protected ambiguous association. This heuristic confers no naming confidence, parent relationship, ownership or automatic selection.

Identity correction: friendly names use a separate versioned local index (4,000 records, 4 MiB, two-year retention from observation). Capture bundle-derived names and direct embedded app/extension parent relationships while the bundle exists; migrate prior snapshot name evidence before replacing inventory. Retain only identifier, name, optional vendor, source, parent identifier and timestamp. Last observation never means confirmed uninstall. Exact-ID local preferences/manifests and removal records provide additional naming provenance. Application grouping uses explicit parent relationships, never equal names or identifier prefixes; this supersedes the product-name grouping rule below. Unknown names fall back to distinct identifiers. Naming confidence, parent association, file ownership and cleanup eligibility remain independent.

Installed Applications remains the current scanner-backed inventory. Recently Removed Applications is a minimal, local record created only after Macventory observes a confirmed real uninstall: name, bundle identifier, source/evidence, original path and time; it is not an indefinitely retained inventory. Leftover Data is an independent review surface that combines those records with bounded retrospective identifier-led discovery for applications removed outside Macventory. It does not require an app bundle or previous Macventory record, but absence is never treated as ownership proof.

Manage Application permits independently eligible normal Quit, Force Quit, Clear App Data and Uninstall selections. Running targets require matching canonical bundle URL plus bundle identifier from `NSRunningApplication`; Force Quit is a confirmation-gated native request, warns about unsaved work and excludes Apple/protected components. The multi-operation ordering is revalidation, process action, verified process exit, native Trash of selected data, then eligible uninstall. A failure that makes subsequent data/uninstall unsafe stops the sequence; results are per-step and not described as atomic.

Data discovery is bounded to accessible user-Library sources. Exact bundle-ID containers, preferences, application support/cache/log/WebKit directories and saved state are Verified App Data. Exact display-name paths remain Possible Related Files; Group Containers and other shared/protected items are displayed but ineligible. User Documents, Downloads, Desktop and external paths are not scanned. A user may deliberately add a single file/folder for review; it is always possible-only and excluded from Select All Verified Data. Native Trash cleanup revalidates file identity, current root containment, no symlink components, permissions, duplicates and nested target conflicts. It never falls back to recursive shell deletion.

## 28. Unified management and discovered leftovers — build 104 (authoritative UI correction)

Single-click selects/details; double-click/Return and Uninstall… open the same application-name-titled management sheet. Right-click preserves Copy/Reveal actions, conditionally shows Force Quit for an exact running identity, and removes standalone Clear App Data/Manage Application entries. The sheet offers Force Quit, Clear App Data and Uninstall checkboxes with independent eligibility, full identity, targets, sizes, classification and explicit acknowledgment. Operation-specific confirmation is single-use. Completed, partial, failed and cancelled states have one OK button; no modal flag may outlive its content. All selected targets are validated before side effects; later steps stop on failure. Native Trash callbacks time out to an honest unknown-outcome error and cannot resume twice. Queued inventory updates occur after dismissal.

The primary Leftover Data overview contains only groups with actual discovered candidates. History remains separate. Retrospective discovery is generic: supported Library direct-child identifiers, exact preference identities, container/saved-state paths and bounded local Info.plist/package manifests. Inventory and Launch Services exclude currently installed/reinstalled apps. Application grouping is default and may combine only identities with an independently recorded or metadata-backed product name; Identifier grouping remains technical and separate. Unknown retrospective ownership and stale history remain possible-only; shared containers remain protected. Search/confidence filters, exact paths, sizes, contents summaries, individual selection, Reveal, refresh and a visible trash-icon/text action are required. Partial scans preserve observations, show structured location/reason/permission/retry details, and block candidates only in an affected location; each selected target still receives fresh ownership, identity and installed-app preflight. Failed/cancelled scans disable cleanup. Successful cleanup refreshes affected groups exactly once. Synthetic QA cannot receive production executors; real destructive verification remains forbidden in this pass.

## 29. Macventory v1.1.0 — current implemented scope

This section supersedes earlier app-only cask limits, manager-wide guided-only assumptions, blanket no-privilege/network statements, process/data UI labels and same-name grouping rules. Earlier build-specific requirements remain historical context. Implementation is distinct from fixture, hosted-CI and real-effect validation.

- **Unified review:** Direct Uninstall, Interactive Uninstall and Guided Only are per-installation capabilities; Protected / Blocked independently overrides unsafe/protected targets. Preview exposes exact identity/version/source, scope, evidence and verification. Opening review executes nothing. Immutable plan-bound acknowledgment is initially unchecked and single use; fresh checks and concurrency guards remain mandatory.
- **Manager support:** eligible reviewed Homebrew app/font/owned-binary casks and single-version formulae can use official normal uninstall. Dependents, services, unsafe effects or ambiguous evidence require guidance/blocking. Exact MacPorts versions/variants and supported mutable current-user named manifest-v3 Nix profiles (Nix 2.28–2.35) have direct adapters. No force/zap/dependency override, store GC, receipt forgetting or strategy fallback is allowed. Missing Homebrew artifacts can cause normal uninstall to fail; success is not guaranteed.
- **Bundle/vendor/provider scope:** independently eligible standalone, Store and limited PKG bundles can use recoverable native Trash after complete ownership/signing/path/process checks. Trusted embedded vendor tools take precedence for PKG/unmanaged apps; verified unique Steam App IDs can use targeted interactive handoff. Launch returns Waiting for User. Setapp/Toolbox remain guided where no trustworthy supported targeted integration is established. Bundle absence does not establish removal of every vendor component or personal file.
- **Health:** manager registration, expected artifact presence and historical metadata are separate facts. Status/Attention Required expose missing payloads, partial, protected, historical and unverified observations without automatic repair or deletion. Separate physical copies remain separate; failed scans do not establish absence. Installation verification does not imply removal eligibility.
- **Management/data:** the application-name sheet offers independently eligible Force Quit, Clear App Data and Uninstall. Validate all targets, verify process exit, move selected data, then uninstall; critical failure stops later actions. Interactive verification preserves prior step results and cannot verify a skipped/completed removal. Terminal results have one OK; refresh follows dismissal. Leftover Data is optional and separately confirmed, with individual exact-path review of possible/personal candidates and protected/shared blocking. Application grouping requires recorded embedded-parent relationships, never equal names/prefixes.
- **Authorization:** only the narrow MacPorts route can request privileges. It requires trusted matching app/helper signing, authenticated XPC peers, explicit OS background-helper approval and per-request administrator rights checked before preflight and the final effect. Default ad-hoc builds cannot use this root route. Discovery/installation never registers a helper; nothing queues while approval is pending. No arbitrary privileged command/file/process API, password collection or protection bypass is permitted.
- **Network and storage:** inventory works locally without a backend or network. Explicit official-guidance opening uses a bounded ephemeral HTTPS HEAD check with same-provider redirects, followed by browser navigation. Page text is never executed. Application cache/preferences/identity/removal records and explicit exports are distinct from separately confirmed manager/Trash effects. Retained identity names do not confer ownership.
- **Diagnostics and distribution:** synthetic QA uses isolated state, persistent QA markers and injected effects. Hosted trace evidence is created by the app in private bounded files and read by the sandboxed controller; it does not alter selection behavior. Production packaging remains arm64, ad hoc and unnotarized, including helper metadata and private compiler-path checks. Full CI must validate the exact final commit with all 16 primary GUI cases and diagnostics; package-only/isolated runs are insufficient.

Current source/removal matrices: [source support](Docs/SOURCE_SUPPORT.md), [uninstall](Docs/UNINSTALL.md). Actual provider removal, native Trash/restoration, signed-helper lifecycle, minimum-OS runtime, clean-machine Gatekeeper and full VoiceOver remain unverified. No release readiness follows from compilation or synthetic success. Version **1.1.0 / build 108** stays unchanged during documentation preparation; the owner creates the tag/release only after final CI and applicable release review. See [release sequence](Docs/RELEASING.md).
