# Installation-source support

Current discovery scope for **v1.1.0 / build 108** is listed below. Detection, installation health and removal eligibility are separate capabilities: a recognized source does not imply automatic uninstall support. See the [current removal matrix](UNINSTALL.md#current-source-specific-removal-support) and [verification status](VERIFICATION.md). Historical execution/audit reports retain their original test counts and branch state.

All ten categories exist in the UI, plus Unknown / Ambiguous. A zero result, absent manager, unsupported layout and failed scan are distinct states. “Fixture verified” does not mean verified against a real installation.

| Source | Implementation / evidence | Actual verification and limits |
|---|---|---|
| Direct / Unmanaged | Bounded native bundle enumeration, canonical paths, bundle metadata | Real Mac comparison passed; exact DMG/ZIP/download provenance is unknown. System apps are hidden by default. Independent standalone Trash eligibility does not promote inferred source confidence; see uninstall boundaries. |
| Mac App Store | Local receipt presence, explicitly inferred | Positive/negative fixtures; real scan returned no receipt-bearing apps. Receipt cryptography, purchase validity and account history are not verified. |
| Homebrew Casks | Installed receipt artifact/config mapping to existing bundles | Real casks match read-only Homebrew listing and merge with native apps. Declared missing apps with current installed tokens are actionable health warnings; failed manager queries are unverified, and metadata for absent tokens is historical. Old/non-app formats may lack artifact mapping. |
| Homebrew Formulae | Installed keg receipts, versions, linked/opt-linked state | Real names/kegs verified. Optional keg-only metadata is shown only when available; otherwise Unknown. No recipe evaluation or metadata download. |
| PKG Installers | pkgutil receipt info and file-list evidence, existing payload matching | Real receipt queries and fixtures verified. Orphan/unmapped receipts stay package records, not confirmed installed applications. Package footprint often unavailable. |
| MacPorts | Documented installed/contents queries | Version/parser and command fixtures; manager absent here. Shared-prefix footprint is not attributed to one package. No live verification. |
| Nix | Offline modern current-user profile JSON, legacy installed-query fallback | Modern/legacy positive and malformed fixtures; Nix absent here. Arbitrary profiles, system closures and shared dependency accounting are unsupported. |
| Setapp | Provider installation roots plus embedded Setapp.framework | Positive/negative fixtures only. Inferred Setapp variant evidence; active subscription/management is not authenticated. Other framework/layout variants unsupported. |
| Steam | Local libraryfolders/appmanifest KeyValues and existing payloads | Parser/game/path-escape fixtures; Steam absent here. Adapter is experimental; downloads/partial manifests may not establish complete installation. Build ID is not product version. |
| JetBrains Toolbox | Legacy Toolbox/apps layout plus bounded, explicitly Toolbox-generated launcher scripts pointing to an existing JetBrains IDE | Legacy and modern launcher fixtures pass, including spoofed/dynamic launcher rejection and neutral unverified stale-target references. Modern association is inferred, not verified removal ownership. Toolbox is absent here; no live-provider verification. Modern installs without a recognized generated launcher remain unmanaged. |

Core application discovery still includes software whose manager cannot be identified. Source failure cannot be interpreted as a successful zero. The app does not authenticate or install any provider to improve coverage.

Primary interface references:
- [Homebrew installed JSON/query documentation](https://docs.brew.sh/Querying-Brew)
- [Nix profile list](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-list)
- [MacPorts installed packages](https://guide.macports.org/#using.port.installed)
- [JetBrains legacy macOS Toolbox layout](https://plugins.jetbrains.com/docs/intellij/app-code.html)
- [Apple Spotlight metadata](https://developer.apple.com/library/archive/documentation/CoreServices/Reference/MetadataAttributesRef/Reference/CommonAttrs.html)

Modern launcher locations follow [JetBrains command-line guidance](https://www.jetbrains.com/help/idea/working-with-the-ide-features-from-command-line.html). Scripts are read, never run. See [machine comparison](INVENTORY_AUDIT.md) and [source-specific uninstall support](UNINSTALL.md).
