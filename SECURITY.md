# Security and privacy

Macventory reads installed software metadata with the current user's permissions. It does not request Full Disk Access, administrator rights, or elevated helpers. Discovery never modifies installed software. A separate single-app uninstall workflow requires a fresh verified plan, plan-bound checkbox confirmation; it never requests elevation or removes dependencies or user data. See [uninstall boundaries](Docs/UNINSTALL.md). Actual destructive behavior has not been verified.

External queries use a typed allowlist, validated executable paths and argument arrays rather than a shell. Commands have time/output limits and cancellation. Manifests, directory traversal and cache size have bounds. Package scripts and provider frameworks are never executed by discovery. The narrowly scoped production uninstall adapter can invoke Homebrew only for a validated single-app cask with no removal hooks. QA injects a simulated executor; no test invokes the production adapter.

Inventory data stays on the machine. Cache and preferences are application-owned; diagnostic export is user initiated and contains only source counts/status. Full development inventory exports may contain sensitive paths and names.

Treat every installed bundle and manifest as untrusted input. Report reproducible crashes, unsafe path handling, privilege issues, unintended writes or unexpected network access with a minimal sanitized fixture. The [official repository](https://github.com/vadimtanel/MacVentory) is public; a private security contact has not yet been configured; arrange a private channel with the maintainer before disclosing sensitive details. Do not invent a contact address or post secrets publicly.

Ad-hoc signatures are for local/development use, not proof of a Developer ID publisher. Do not weaken Gatekeeper or privacy controls to run a downloaded artifact.

The public screenshot mode (`--demo`) contains only fictional records with no filesystem targets. It bypasses real scanning/cache/preferences, disables cache maintenance, uses in-memory column customization and cannot invoke live removal. Demo records are rejected by the uninstall planner even outside the demo UI.

Macventory 1.0.0 keeps preview separate from execution: native row double-click/Return opens only review, including blocked guidance. The initially unchecked checkbox is tied to the exact plan UUID, not a typed application name. Fresh validation and duplicate/concurrent request rejection remain mandatory. Free/ad-hoc signing is intentional; no paid membership/notarization is required. Users may make a supported per-app Gatekeeper exception themselves where available; Macventory never changes quarantine or system security policy.
