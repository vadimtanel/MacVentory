# Settings, Information and About

Settings is available in the sidebar footer and the standard macOS application menu. All four pages edit one draft. The fixed page selector stays above scrollable, top-aligned content.

## Done, Cancel and close

Opening Settings copies the current configuration into a draft. Edits do not alter the active inventory configuration or persisted preferences. Appearance remains unchanged while editing; it applies only after Done. **Done** validates and saves one configuration, then requests at most one refresh if scan locations/executables/external-volume or system-application discovery changed. Appearance, absent-source visibility, sorting, smart-view thresholds and future launch behavior do not cause an immediate rescan. **Cancel** or closing without Done discards pending edits, including edits on other pages. Concurrent stale drafts are rejected instead of overwriting newer settings.

Local absolute paths and ~/ paths are accepted; URLs/control characters are rejected. A configured path may be temporarily absent, such as an external volume. Managers are not installed or elevated. Explicit diagnostic export/cache maintenance actions are separate from draft configuration; cache maintenance is disabled in isolated demo/test modes.

## Pages

| Page | Purpose |
|---|---|
| General | System-app discovery/visibility, absent-source visibility, appearance and the initial sort for new inventory windows. Visibility never authorizes removal. |
| Scanning | Scan on launch, supported mounted external locations, extra app directories (one per line), Homebrew/Toolbox roots (commas), local MacPorts/Nix executables. Relevant changes refresh once on Done. |
| Discovery | Recently Installed1–365 days; Possibly Unused1–3650 days, default 180. Type numbers or use steppers. Large Applications offers explicit500 MB/1 GiB/5 GiB/10 GiB thresholds. |
| Information | Scanner status, source availability/limitations, sanitized diagnostic export and inventory-cache scope. Failed, Unsupported, Empty and Not Installed are different states. |

Installation dates require reliable evidence, not file creation. Missing last-opened metadata never means unused. Logical payload size is informational, not guaranteed reclaimable space. Discovery is read-only; uninstall is a separate confirmed operation.

Diagnostics export only source status/counts, excluding names, paths, identifiers and raw errors. Cache clearing affects only Macventory's saved snapshot, never installed software. Neither action was invoked against real data during this QA pass.

## About and link configuration

About displays official artwork, runtime version, tagline, creator/copyright and Apache 2.0 credit. `AppLinks` in Sources/MacventoryCore/SettingsInput.swift defines the exact native link targets:

- [LinkedIn](https://www.linkedin.com/in/vadim-tanel/)
- [GitHub profile](https://github.com/vadimtanel/)
- [Official Macventory repository](https://github.com/vadimtanel/MacVentory)

There are no repository-link placeholders. Semantic SF Symbols accompany readable link text; no third-party LinkedIn/GitHub logo files were copied. External browser navigation was not used as a test of web content.

## Screenshot mode

Launch the built app with `--demo`. It uses13 fixed fictional records across all ten sources, no real installation paths, isolated configuration and in-memory column state. It neither scans real providers nor loads/writes the real inventory cache/preferences. Cache clearing and removal are disabled; the planner independently rejects demo records. No app bundles are created by demo mode. Public captures live in Docs/Screenshots/ and show the actual native app.

## 1.0.0 appearance correction

Settings now renders using the committed model appearance, never the draft value. Choosing Light/Dark/System changes only the picker selection until Done. Actual GUI verified Light→Dark and Dark→Light staging with unchanged colors, System staging, Escape/Cancel/native-close discards and Done applying Dark. Reopening retained the committed value. Appearance-only commit caused zero refreshes; a subsequent system-discovery commit caused one simulated refresh. Real preferences were not modified for QA; Codable round-trip tests cover the saved configuration representation.
