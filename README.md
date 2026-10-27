<p align="center"><img src="Design/Branding/brand-lockup-reference.png" width="260" alt="Macventory official logo"></p>

# Macventory 1.1.0

### Know what's on your Mac.

A free, native macOS application for understanding installed software: where it came from, which version is present, how much space its payload uses, and what is known about installation and usage dates.

## Macventory v1.1.0 — Uninstall & Installation Health

**v1.1.0 is upcoming; its GitHub Release and downloads have not been published.** This repository prepares version 1.1.0 / build 108. Use the [latest published release](https://github.com/vadimtanel/MacVentory/releases/latest) for available downloads; [v1.0.0](https://github.com/vadimtanel/MacVentory/releases/tag/v1.0.0) is the first published release.

The planned v1.1.0 release contains an Apple Silicon DMG (recommended), ZIP alternative, SHA-256 checksum file and source archive. See [installation and expected filenames](Docs/INSTALLATION.md) and the [v1.1.0 changelog](CHANGELOG.md).

[All Releases](https://github.com/vadimtanel/MacVentory/releases) · [Installation instructions](#installation)

[Official repository](https://github.com/vadimtanel/MacVentory) · [Created by Vadim Tanel](https://www.linkedin.com/in/vadim-tanel/) · [![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)

**Apple Silicon · macOS 13.0 configured minimum · Upcoming: v1.1.0 / build 108**

![Actual Macventory app in Light Mode with fictional demonstration records](Docs/Screenshots/macventory-inventory-light.png)

The image is an actual native-app capture using isolated demo data. Every software name and observation shown is fictional; no personal inventory is used in public screenshots. The retained screenshots show earlier UI/builds and do not establish v1.1.0 runtime or release validation.

## Overview

Macventory helps developers, power users and anyone maintaining a Mac answer a simple question: what is installed here? It brings application bundles and supported package-manager records into one searchable inventory, while preserving the difference between verified facts, inferred ownership and unavailable metadata.

Two discoveries of the same physical app can become one row. Separate copies and separate installed package versions remain separate. Unknown dates stay unknown; filesystem creation is never passed off as an installation date.

## Features

- Native source sidebar, inventory table, application icons and evidence-aware details.
- Ten installation-source categories, plus Unknown/Ambiguous.
- Versions, paths, logical payload sizes, installation events and last-opened observations where reliable.
- Search names, identifiers and paths; combine source, kind, confidence, size and date filters.
- Sort by Name, Version, Source, Status, Size, Installed or Last Opened. New fields start ascending; repeated clicks reverse. Missing values stay last, numeric versions compare naturally, and selection remains stable.
- Optional column visibility/customization on macOS 14+, with a fixed-column macOS 13 fallback.
- Recently Installed, Possibly Unused, Large Applications, Unknown Metadata and **Attention Required** smart views.
- Local snapshot cache, progressive scans, cancellation, sanitized diagnostics and settings drafts.
- Unified single-installation removal review with **Direct Uninstall**, **Interactive Uninstall**, **Guided Only** and independent **Protected / Blocked** safeguards.
- Installation health separates manager registration, expected application/payload presence, historical receipts and incomplete observations; discovery never repairs or removes software.
- Application management: verified-process Quit/Force Quit, source-aware Clear App Data, and a dedicated **Leftover Data** view for residual data after removal.

## Screenshots

[Light inventory](Docs/Screenshots/macventory-inventory-light.png) · [Dark inventory](Docs/Screenshots/macventory-inventory-dark.png) · [Settings](Docs/Screenshots/macventory-settings.png) · [About](Docs/Screenshots/macventory-about.png)

[Leftover Data overview with synthetic QA candidates](Docs/Screenshots/macventory-leftover-data.png)

<details><summary>Dark Mode</summary>

![Actual Macventory demo in Dark Mode](Docs/Screenshots/macventory-inventory-dark.png)

</details>

<details><summary>Settings and About</summary>

![Discovery settings with draft confirmation controls](Docs/Screenshots/macventory-settings.png)

![About with creator and official repository links](Docs/Screenshots/macventory-about.png)

</details>

## Compatibility

| Item | Target / actual evidence |
|---|---|
| Processor | Apple Silicon M1, M2, M3, M4 and M5 are intended targets; they have not each been independently tested. |
| Actual runtime | Apple M4 Pro on macOS 27.0.1. |
| Minimum deployment | macOS 13.0, configured; minimum-OS runtime is still unverified. |
| Primary binary | arm64. |
| Intel | Optional compatibility is preserved; Intel is not a required release target and current runtime support is not advertised as verified. |
| Tests | Swift Testing requires a macOS 14+ test host. Full Xcode is needed for Xcode-project/XCUITest validation. |

## Installation

### Homebrew installation

For most users with Homebrew installed, one command is sufficient:

```bash
brew install --cask vadimtanel/macventory/macventory
```

Homebrew automatically adds the [Macventory Tap](https://github.com/vadimtanel/homebrew-macventory) and downloads the official release DMG, verified against the Cask's SHA-256. Adding the Tap manually is optional:

```bash
brew tap vadimtanel/macventory
brew install --cask vadimtanel/macventory/macventory
```

Use the fully qualified name to identify the project's Cask. Homebrew manages Tap trust and any prompts under its [Tap Trust guidance](https://docs.brew.sh/Tap-Trust).

To update:

```bash
brew update
brew upgrade --cask vadimtanel/macventory/macventory
```

Homebrew installs the version currently offered by the separate Tap. v1.1.0 becomes available there only after its stable GitHub Release is published and the Tap automation detects and validates it; synchronization may be delayed. See the [latest stable release](https://github.com/vadimtanel/MacVentory/releases/latest) and [Tap documentation](https://github.com/vadimtanel/homebrew-macventory) for availability.

Homebrew is optional: direct [DMG and ZIP downloads](https://github.com/vadimtanel/MacVentory/releases) and the manual instructions below remain available. The application is currently ad-hoc signed and **not Apple-notarized**. Homebrew installation does not bypass Gatekeeper; review the [first-launch guidance](#first-launch-and-gatekeeper).

### Recommended DMG installation

1. Open the [latest published release](https://github.com/vadimtanel/MacVentory/releases/latest) and download its arm64 DMG and checksum file. v1.1.0 is not yet available.
2. Verify the download, then open the DMG. The planned v1.1.0 filename is `Macventory-1.1.0-arm64.dmg`.
3. Drag Macventory.app onto the Applications shortcut.
4. Eject the disk image.
5. Launch Macventory from Applications or Spotlight.

The disk contains the complete app and a visual installation guide. No command-line installation or administrator helper is required.

![Actual Finder installation window](Docs/Screenshots/macventory-installer.png)

### Alternative ZIP installation

1. Open the [latest published release](https://github.com/vadimtanel/MacVentory/releases/latest) and download its arm64 ZIP and checksum file.
2. Verify and extract the ZIP to obtain Macventory.app. The planned v1.1.0 filename is `Macventory-1.1.0-arm64.zip`; it is not yet available.
3. Move Macventory.app into Applications.
4. Launch the application.

End-user Macs do not need SwiftPM, Xcode or development files.

### Integrity verification

Download the SHA-256 checksum file from the same [official release](https://github.com/vadimtanel/MacVentory/releases/latest) as the artifact. If comfortable using Terminal, calculate the downloaded artifact's checksum with:

```sh
shasum -a 256 <filename>
```

Replace `<filename>` with the downloaded DMG or ZIP filename and compare the result with its entry in the checksum file. Checksum verification is separate from installation. A checksum detects a mismatch but does not independently establish who published the file.

To update a manual installation, quit Macventory normally, verify the new published download, then replace the existing app in Applications. Homebrew installations should use the upgrade command above. See [updating and verification](Docs/INSTALLATION.md#updating-an-existing-installation).

### First launch and Gatekeeper

This project intentionally uses free tools and local **ad-hoc signing**, without paid Developer ID certificates or Apple notarization. An installable app bundle contains the program/resources; an ad-hoc signature seals local code integrity. Developer ID identifies an enrolled developer, notarization is Apple's separate assessment, and Gatekeeper applies macOS launch policy. These are different checks.

A download may be blocked. Attempt to open it and inspect the warning. If you independently trust the official source and checksum, macOS may offer **System Settings → Privacy & Security → Open Anyway**, followed by its normal confirmation prompt. This is a user decision; Macventory never approves itself, clears quarantine or disables protections. Do not bypass malware/damage warnings or disable Gatekeeper/SIP. Availability can depend on macOS and organizational policy; launch on every Mac is not guaranteed. See [Apple's supported procedure](https://support.apple.com/102445) and [installation details](Docs/INSTALLATION.md).

## Quick start

Command-click inventory sidebar categories to combine them. The table includes software matching any selected category, then applies search and filters; overlapping installations appear once. Selecting All Software resets the selection. Leftover Data remains a separate page.

1. Open Macventory. With Scan on launch enabled, the app refreshes automatically; otherwise choose **Refresh Inventory**.
2. Browse Library, Smart Views or an installation source. Sidebar counts exclude hidden system apps; the footer distinguishes shown and total records.
3. Search by name, identifier or path. Open **Filter Software** to narrow results further.
4. Click a column header to sort, then click it again to reverse the direction. Use **Columns** to choose visible fields where supported.
5. Select a row to inspect its metadata and source evidence. Reveal its location or copy its identifier/path from details.
6. Open Settings from the sidebar footer. **Done** validates and applies a draft; **Cancel** or closing without confirmation discards it.

## Installation sources

| Source | Current verification / scope |
|---|---|
| Direct / Unmanaged | Live bundle enumeration verified; a DMG/ZIP download origin cannot be inferred from the bundle alone. |
| Mac App Store | Local receipt evidence is inferred. Positive cases are fixture tested; purchases/receipt cryptography are not authenticated. |
| Homebrew Casks | Live receipt/artifact mappings and native-app merging verified for recognized formats. |
| Homebrew Formulae | Live installed names, keg versions and receipt timestamps verified; separate kegs remain separate. |
| PKG Installers | Live receipt/payload matching verified. A receipt alone does not prove an application still exists. |
| MacPorts | Documented queries and parser fixtures; no live installation on the development Mac. |
| Nix | Supported current-user modern/legacy profile formats fixture tested; arbitrary profiles/system closures unsupported. |
| Setapp | Recognized provider/framework evidence fixture tested and inferred; no live provider verification. |
| Steam | Local library/manifests fixture tested; experimental adapter, no live provider verification. |
| JetBrains Toolbox | Legacy layout and modern generated-launcher association fixture tested. Modern association is inferred; unknown layouts remain unmanaged. |

See the [supported-source matrix](Docs/SOURCE_SUPPORT.md). Missing, empty, unsupported and failed sources are different outcomes. Categories can overlap; discovery counts are not a sum of unique installed applications.

## Smart views

- **Attention Required:** actionable installation inconsistencies and partial states, including a missing app whose manager registration remains. Inspect the evidence; a warning never authorizes removal.
- **Recently Installed:** a verified installation event within the configured number of days. File creation is a separate fact.
- **Possibly Unused:** a recorded opening older than the threshold, default 180 days. Missing usage never means unused; Spotlight history may be incomplete.
- **Large Applications:** payload size at or above the selected threshold. Logical size excludes external data and does not guarantee reclaimable disk space.
- **Unknown Metadata:** records missing important metadata such as size, install time or last-opened information.

## Installation health

The compact **Status** column and details distinguish **Verified Installed**, **Attention Required**, **Protected / System**, **Unknown / Unverified**, **Partially Removed** and **Receipt Only / Historical**. Details show expected paths, observed presence, manager registration and check time where available. “Verified Installed” describes observed installation state; removal eligibility is assessed separately.

A missing Homebrew app can remain registered as a cask; a PKG receipt can outlive its payload. Neither is a second installed app. A CLI-only package does not require an application bundle. Separate physical copies stay separate even when names or identifiers match. Failed or incomplete scans remain unverified/stale rather than establishing absence. Refresh installation status after manual or guided work; Macventory does not automatically repair, reinstall or clean these records.

## Uninstall

Double-click a row, press Return, or choose **Uninstall…** to open the application-management dialog, titled with the application name. Select independently eligible **Force Quit**, **Clear App Data**, and **Uninstall** actions, review the exact targets and warnings, then check the review checkbox and confirm. The final button names the selected actions. Opening the dialog never starts an operation. Results use operation-specific status and one **OK** button, which fully dismisses the sheet; completed actions cannot be submitted again.

The preview explicitly shows **Direct Uninstall**, **Interactive Uninstall**, **Guided Only** or a **Protected / Blocked** safety override for the selected installation. Eligible Homebrew Casks/Formulae, exact MacPorts versions/variants and supported modern mutable Nix profile elements use official manager operations. Trusted local vendor uninstallers and uniquely targeted Steam games use an interactive handoff with separate verification. Eligible standalone, App Store and limited PKG bundles can use native recoverable Trash after independent ownership and filesystem checks. Setapp/Toolbox use documented guidance when no trustworthy targeted integration can be established.

A root-owned MacPorts installation requires a matching signed app/helper and explicit macOS approval; an ad-hoc development build cannot authorize that route. No uninstall is queued before approval. Scope and expected effects are reviewed before confirmation. Bundle-only removal may leave external components and data. Vendor launch is **Waiting for User**, and **Verify Removal** checks the resulting state. Leftover Data remains a separate optional review.

There is no bulk uninstall, force, zap, automatic dependency removal, store garbage collection or automatic data sweep. Failed operations never silently switch strategies. A started external operation cannot guarantee cancellation or rollback.

**Real destructive provider execution remains unverified.** Tests invoke production adapters through fake effect boundaries and disposable fixtures; live inspection is read-only. Signed-helper deployment and full CI on the final documentation commit remain unverified. See the [current removal support and limits](Docs/UNINSTALL.md), [historical independent audit](Docs/UNINSTALL_FINAL_AUDIT.md) and [verification status](Docs/VERIFICATION.md).

## Application management and Leftover Data

Cleanup moves each selected folder whole, including its contents; parent folders and unselected locations remain. Leftover Data shows whether personal-folder discovery is enabled and links directly to Scanning Settings. Permission failures identify the failed check or Finder request and provide access guidance. Macventory cannot grant itself macOS privacy access or guarantee that protected container cleanup will be allowed.

Individual cleanup results distinguish missing targets: **No Longer Exists** means the target was already absent and Macventory did not delete it. Confirmed missing targets leave the active list immediately; permission failures, changed targets and unknown Finder outcomes remain distinct. Partial scans also reconcile retained observations, without interpreting access errors as missing files. Unknown Trash outcomes are never automatically retried.

If a friendly name is unavailable, a distinctive folder name may provide a bounded lead through the final identifier component. The UI explains that this association is uncertain; broad names are excluded, ambiguous matches stay protected, and the suggestion never establishes ownership or a product name.

Under **Settings → Scanning**, **Discover related folders in Documents, Downloads and Desktop** is off by default. When enabled, bounded direct-child searches suggest folders using known local application names or exact identifiers. These remain **Possible Related Files — Manual Review Required**, excluded from Select All Verified Data. Each needs individual selection, exact-path review and confirmation. Shared, ambiguous, linked or unsafe locations stay blocked. A folder name is never proof of exclusive ownership.

Application identity correction: friendly names are retained separately from installed inventory in a local `application-identities.json` index (schema 1, 4,000 records, 4 MiB, two-year retention). Records contain identifiers, names, optional vendor, parent relationship, source and last observation, without installation paths or usage history. Existing snapshot name evidence is migrated before refresh. Local removal records and exact-ID preference/manifests also supply names. Grouping requires recorded embedded-bundle parent relationships: equal display names or identifier prefixes never merge products. Unresolved names display distinct identifiers. Naming never upgrades ownership or cleanup eligibility.

The context menu retains Copy Identifier, Reveal in Finder, Copy Path and Uninstall…. **Force Quit** appears only for a safely matched running app. Matching uses canonical bundle URL, bundle identifier, process identifier and launch time; process exit must be observed before later steps proceed. Unsaved changes may be lost. Quit normally from the app to save work first. System components and Macventory’s own process are protected.

**Clear App Data** is independent of uninstall. Macventory checks only bounded, normally accessible Library locations using exact bundle identifiers: containers, exact support/cache/log/WebKit directories, saved state and preferences. Exact identifiers are **Verified App Data**; exact display-name directories are **Possible Related Files** and require individual selection; group containers and shared/protected data cannot be moved automatically. The action uses Finder’s Trash, never permanent recursive deletion. It revalidates path identity, roots, symlink safety and nesting immediately before submission and reports every skipped or failed item.

**Leftover Data** lists only groups with discovered, existing candidates. Minimal removal history is retained separately and does not create empty cleanup entries. A general scan of supported Library sources discovers exact preference/cache/container/support/saved-state identifiers and bounded local manifests, even without a previous inventory record or app bundle. There are no product-specific discovery hints. Installed and reinstalled applications are excluded using inventory and Launch Services. Retrospective associations and stale history remain possible-only; absence of an app is not proof of exclusive ownership.

The default **Group by: Application** view combines identities only when recorded embedded-bundle parent relationships establish the association; equal display names or raw identifier resemblance never join groups. **Identifier** retains the technical one-identifier view. Search and confidence filters operate in both views. **Select All Verified Data** excludes possible, personal, shared and protected data. Possible-related files may be selected one at a time only after reviewing their exact path and confirmation warning. **Move Selected to Trash** opens a separate path-by-path review with a checkbox. A partial scan names the affected locations and blocks only candidates in those locations; independently verified targets remain subject to the same fresh ownership, identity and installed-app checks. Failed or cancelled scans require a retry. Documents, Downloads and Desktop discovery is limited to the opt-in direct-child searches described above; external volumes are not swept. Individually nominated personal subfolders within the current home can also be reviewed. Broad home/Library roots, application bundles and linked paths are rejected.

Combined operations validate targets first, verify Force Quit, move approved data to Trash, then perform eligible uninstall. Failures stop later steps and preserve individual results. A Finder request that times out is reported as unknown and may still finish; the UI remains dismissible and does not retry automatically. Success uses “Operation completed.” with a separate operation-specific explanation; simulation always states that nothing changed.

## Settings

- **General:** visibility, appearance and default sorting.
- **Scanning:** launch behavior, supported external locations, additional application/provider roots and manager executable paths.
- **Discovery:** typed day thresholds/steppers and explicit large-size choices, with plain-language explanations.
- **Information:** scanner status, source availability, sanitized diagnostics and inventory-cache scope.

Every page edits the same draft. Done validates, persists once and requests at most one refresh if scan locations or system-application discovery changed. Appearance, sorting, absent-source visibility and threshold changes do not restart discovery. Cancel, Escape or window close discards pending changes. Appearance stays unchanged until Done. Explicit maintenance/export actions are separate from saving settings. See [Settings guidance](Docs/SETTINGS.md).

## Privacy and security

Inventory processing and cache storage are local. There is no backend, account system or telemetry. Discovery never modifies installed software or asks for administrator privileges. External profile/repository links open only when chosen by the user.

Snapshots are stored in `~/Library/Application Support/Macventory/inventory.json`. Sanitized diagnostics include source status/counts, excluding application names, paths, identifiers and raw errors. Full development snapshots are private and must not be uploaded.

Public captures use `--demo`: no real scans, no real cache/preferences, fictional records with no filesystem targets, disabled removal and isolated column state. See [Security](SECURITY.md) and the [publication review](Docs/PUBLICATION_REVIEW.md).

## Building from source

Use a Swift 6 toolchain and macOS SDK. The current source uses APIs from SDK 26 behind runtime availability checks, so an SDK 26+ development environment is needed even when targeting macOS 13.

```sh
git clone https://github.com/vadimtanel/MacVentory.git
cd MacVentory
bash scripts/build-app.sh release
open build/Macventory.app
```

Development commands:

```sh
bash scripts/swift-tool.sh test --disable-xctest
MACVENTORY_LIVE_TESTS=1 bash scripts/swift-tool.sh test --disable-xctest
open -n build/Macventory.app --args --demo
bash scripts/package-release.sh
python3 scripts/review-publication.py
```

The build produces a native app with resources, license/NOTICE and an ad-hoc signature. A narrowly scoped MacPorts helper is bundled but is not activated by installation or scanning; its privileged route needs trusted matching signing and explicit OS approval. Packaging prepares ZIP, DMG, source archive and SHA-256 files under artifacts/ without committing or uploading anything.

The inspected Swift 6.4 Command Line Tools setup builds with the installed SDK 26.5 because SDK27 lacks its SwiftUI macro plug-in. Its native SwiftPM fallback is deprecated upstream. Restricted environments may need `MACVENTORY_DISABLE_SWIFTPM_SANDBOX=1`; this changes compiler subprocess sandboxing only, not macOS protections. See [release preparation](Docs/RELEASING.md) for final CI and pending release gates.

## Troubleshooting

| Symptom | What to check |
|---|---|
| Not Available / Unknown | The source may not provide the value; privacy/indexing can limit Spotlight. Refresh, inspect evidence and avoid assuming a missing date means unused. |
| A source is absent | Check Information, manager installation and configured local paths. Macventory does not install providers. |
| Scan Failed / Unsupported | Inspect source status; other sources can still finish. Share sanitized diagnostics, not a private inventory. |
| Too few rows | Clear search/filters, check category and Show system applications. Counts reflect visibility rules. |
| Settings do not persist | Use Done. Cancel/window close intentionally discard the draft. |
| Removal is unsupported | Follow the displayed manager/vendor guidance. Do not bypass ownership or protection checks. |
| A downloaded app is blocked | The default distribution is ad-hoc signed and not Apple-notarized. Review the warning and the supported per-app Open Anyway procedure above, if you independently trust the download. |

## Contributing

Use [Issues](https://github.com/vadimtanel/MacVentory/issues) or focused pull requests with synthetic reproductions and actual verification. Keep dependencies minimal and provider formats explicit. Run meaningful tests and a native build; mark unavailable Xcode/UI checks honestly. Never remove real installed software during QA. See [CONTRIBUTING](CONTRIBUTING.md).

## License and credits

Created by **Vadim Tanel**. **Copyright © 2026 Vadim Tanel.**

Licensed under [Apache-2.0](LICENSE); attribution is in [NOTICE](NOTICE). The LICENSE remains the official complete legal text, including its appendix template.

Redistributors must follow Apache 2.0's notice/license/change-marking requirements. We additionally ask forks to credit [the original project](https://github.com/vadimtanel/MacVentory) and [creator](https://www.linkedin.com/in/vadim-tanel/) when practical. That courtesy request adds no license restriction and does not require clickable links in every derivative UI. The app uses native SF Symbols for link affordances rather than copied third-party brand logos.

## Project status

Version 1.1.0 / build 108 includes the merged unified uninstall and installation-health implementation, source-aware adapters, application management, separate Leftover Data review, settings transactions and isolated demo/QA modes. [Verification](Docs/VERIFICATION.md) distinguishes recorded local fixtures, hosted CI and unverified real effects.

The starting source commit passed hosted native build/test/package checks, but its overall run failed the GUI count/order and reporting gates; see [CI evidence](Docs/CI.md). The final documentation commit still requires its own complete hosted workflow before tagging. Full VoiceOver, minimum-OS execution, clean-machine Gatekeeper behavior, actual provider removal and signed-helper deployment remain unverified. Intel is optional. Documentation preparation does not establish **RELEASE READY**; see the [release checklist](Docs/RELEASING.md).
