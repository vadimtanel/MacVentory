# Unified uninstall: execution levels and validation

Development report, 24–25 October 2026. Branch: `feature/unified-uninstall-and-inventory-health`; HEAD: `22334cd`. This report supersedes the earlier pass’s source-removal limits in [Unified uninstall and inventory health](UNIFIED_UNINSTALL_AND_HEALTH.md). The existing 38 staged files were preserved; this continuation remains uncommitted and unstaged. No branch, commit, push, merge, tag, public release or release asset was created or changed.

## Product behavior

Every prepared installation has **Direct Uninstall**, **Interactive Uninstall** or **Guided Only**, with an independent **Protected / Blocked** override. The management preview names the level, actual source and target, removal scope, verification method and evidence. MacPorts/Nix show the exact version/variants or profile/element. Structured arguments are available in the operation disclosure. A missing app does not exclude manager-level operations. Package-only installations remain valid.

The resolver chooses a strategy per installation. Verified official manager operations run directly; supported official interactive workflows launch only after confirmation. A trusted vendor uninstaller precedes limited bundle removal for PKG/unmanaged apps. Unsupported manager ownership, modes or effects get a specific guide. Protected, conflicting, stale, changed or unsafe targets cannot gain removal permission from a health warning. A failed strategy never invokes a different removal mechanism. A different strategy requires a new preview and confirmation.

The checkbox is initially unchecked, resets when selection or plan changes and authorizes only the immutable reviewed plan. Confirmation is single use and consumed before any suspension. Fresh validation precedes the production dispatcher and adapters. Result reporting distinguishes package/registration removal, bundle-only removal, waiting, partial, already absent, failed and unknown outcomes. Interactive launch returns **Waiting for User**; **Verify Removal** independently inspects the result. **Refresh Installation Status** rescans after guided work. Optional **Review Leftover Data Separately** opens the existing independently confirmed workflow. Discovery never repairs or cleans anything.

## Full source coverage matrix

Levels below are the highest implemented eligible outcome, not blanket assignments for every installation in a category. “Mock boundary” means the real production adapter runs with fake effects/registries; no real provider removal, Finder Trash, root-helper registration or vendor launch was performed.

| Source | Highest implemented level | Real production executor | Interactive handoff | Guided fallback | Verification | Tests | Limitations |
|---|---|---|---|---|---|---|---|
| Homebrew Cask | Direct | `HomebrewRemovalAdapter` → `LiveHomebrewOperation`: validated standard brew, normal `uninstall --cask -- token`; declarative app/font/binary targets, multiple apps, configured app/font directories and renames | No general cask wizard is invoked; a reviewed exact-bundle-ID quit directive is supported only with no matching copy running | Executable/script/signal/service/PKG/other unreviewed effects, custom manager trust failures or unresolved artifact mapping; official recovery after normal failure | Requery installed tokens; recheck every reviewed artifact; exit zero alone insufficient | Healthy/orphan scan→plan→confirmation→production adapter→fake mutation→verification→rescan; font/binary/multiple-app cases; rename/custom directory; changed evidence; failures; live read-only casks | Missing artifacts may make normal brew uninstall fail. No force, zap, metadata surgery or deletion fallback. Absolute/nested target overrides and unreviewed artifact types remain unsupported; binary links must point into this cask or its reviewed app bundles. Real removal untested |
| Homebrew Formula | Direct | Same production adapter; normal `uninstall --formula -- token` for one verified keg/version | None needed for eligible packages | Multiple installed versions, dependents, loaded/running/unknown service, changed manager or unsupported prefix | Installed query plus reviewed keg/artifact absence | Formula discovery and direct mock operation; exact args; dependency/version failure; services; CLI-only health; real read-only kegs | No dependency removal, autoremove, service shutdown or universal detection of external consumers; real removal untested |
| MacPorts | Direct, with macOS approval if required | `ManagedRemovalAdapter` → `LiveManagedRemovalBoundary`; exact `port -N uninstall name @version_revision+variants`; signed narrow helper for root-owned registry | Normal OS background-helper approval may be necessary before direct execution; no removal queued before approval | Unsupported prefix, dependents, service/extension payload, unsafe manager/config ownership; root-owned registry in an ad-hoc build without the signed helper | Requery exact installed version/variants; compare other port identities; inspect reviewed app roots or bounded CLI artifact sample | Production discovery→preparation→confirmation→mock manager mutation→verification→rescan; variants, dependency changes, manager replacement, permission/timeout/cancel, partial/query failure, auth pending; shared privileged handler tested with fake boundary | Standard `/opt/local` only. Signed deployment and actual Service Management/XPC authorization have not run. No MacPorts installed locally. CLI sampling is bounded to 64 paths; registry verification is not a full filesystem audit |
| Nix | Direct for verified modern mutable user profiles | `ManagedRemovalAdapter` → exact `nix --offline profile remove --profile <slot> -- <named-element>` | None for supported user-owned profiles | Declarative/system profiles, legacy/indexed formats, unverifiable generation links, unsupported Nix versions or names | Selected element absent; full records of other elements unchanged; mutable profile still valid; store objects/older generations remain | Production scanner→plan→confirmation→mock profile mutation→verification→rescan; generation replacement, version/selector safety, all failure outcomes and unrelated metadata change | Named modern manifest v3, Nix 2.28–2.35; only normal current-user mutable slots. No store-path deletion or garbage collection. Nix absent locally; real profile removal untested |
| PKG Installers | Direct limited bundle removal; Interactive when trusted vendor tool exists | `BundleRemovalAdapter` → native recoverable Trash for an independently eligible exact bundle with only its matching receipt claim; no receipt payload deletion | `VendorRemovalAdapter` → signed associated `Uninstaller.app`, including bounded embedded Frameworks discovery | Historical/unmapped receipts, no safe bundle or trusted tool, shared/service components, incomplete ownership audit | Bundle path absent after native callback; receipt deliberately remains historical. Vendor launch waits; separate path verification reports only bundle absence | PKG receipt discovery→level/scope→confirmation→production bundle adapter/fake move→historical receipt rescan; vendor precedence/signature association, single-use confirmation, fake opener, synthetic completion and rescan; nui regression | No generic noninteractive vendor CLI catalog. A vendor tool needs a reviewed per-vendor scope/contract before direct CLI support. No `pkgutil --forget`, deleting every receipt path or arbitrary web commands. Real PKG/vendor removal untested |
| Mac App Store | Direct limited bundle removal | `BundleRemovalAdapter` → `NSWorkspace.recycle`, after signed/eligible bundle and complete ownership checks | Finder may request normal OS authorization during recycle | Protected Apple components, invalid signatures/receipt evidence, ownership/path/service restrictions | Original bundle path absent; account/purchase records and external user data outside scope | Positive synthetic receipt/signing discovery→plan→single-use confirmation→production adapter with fake move→native rescan; negative protected/signature tests | Local receipt establishes inferred source, not purchase authentication. No undocumented App Store API. Actual Store bundle Trash untested |
| Setapp | Guided Only under currently verified capabilities | None: no supported exact-target removal API found in reviewed official documentation | No reliable documented targeted uninstall handoff found; generic client launch is not presented as uninstall | Match selected app in Setapp and use its removal workflow; official link and rescan | Fresh provider/native observations; framework alone cannot authenticate subscription/registration | Existing provider fixtures, guidance and explicit level-selection tests; no effect boundary invoked | No Setapp install/account locally. This is an integration availability limit, not an assumption that all Setapp software must forever remain guided. No deletion behind the manager |
| Steam | Interactive for a verified unique exact App ID | `SteamRemovalAdapter` with native targeted URL opening in the explicitly verified signed Steam client | `steam://uninstall/<AppID>`; user completes Steam’s confirmation | Missing/untrusted client, unavailable manifest/index, ambiguous duplicate installation, inaccessible library or invalid App ID | Manifest, payload and active library index must all stop reporting the target; partial/unknown kept separate | Production manifest discovery→targeted plan→confirmation→fake native opener→waiting→synthetic payload/manifest/index changes→verification→rescan; duplicate-library rejection | No Steam locally; handoff on macOS not exercised. Valve’s protocol page could not be re-read through its anti-bot page in this session; current documentation and real client behavior remain release validation. No manual game-library deletion; saves/shared content excluded |
| JetBrains Toolbox | Guided Only under currently verified capabilities | None: reviewed official docs describe app/version removal in Toolbox, not a supported exact macOS uninstall CLI/API | No trustworthy targeted handoff found; Windows silent install support is not treated as a macOS removal API | Select the exact IDE/version/path in Toolbox; official link and rescan | New launcher/native observations; inferred association stays inferred | Legacy/modern generated-launcher, spoof/dynamic/path, stale-target and guidance/level tests | Toolbox absent locally; no real removal. No guessed flags or direct managed-directory deletion |
| Direct / Unmanaged | Direct native Trash; Interactive trusted vendor first | `BundleRemovalAdapter` → `NativeBundleTrashOperation` → `NSWorkspace.recycle` | `VendorRemovalAdapter` → official signed associated tool when present | Incomplete audit, unsafe root/path/ownership, vendor services/helpers or no trusted safe mechanism | Require original path absent after corresponding native callback; vendor path check never asserts all external components removed | Native discovery→plan→confirmation→production adapter with recoverable fixture move→absence checks; symlink substitution, callback-with-target-left, data preservation; vendor precedence; GUI level/gating | Standard Applications directories plus explicitly configured narrow user-owned app directories; root-owned signed bundles require writable parent and OS permission. No arbitrary-path deletion, personal-data sweep or complete vendor uninstall claim. Real Finder Trash untested |
| Unknown / conflicting / protected | Protected / Blocked override or justified Guided for insufficient evidence | None | None inferred | Resolve ownership/refresh rather than guessing commands | Fresh evidence only | Conflict/multiple-copy/stale/unsafe selector/system/running-self tests; blocked GUI preview | Cannot force deletion to obtain coverage |

## Production boundaries and authorization

`UninstallPreparationService` centralizes capability selection. `UninstallLevels.swift` defines the typed levels, scopes and immutable managed/interactive evidence. `UninstallExecutionService` dispatches exactly the confirmed strategy. Homebrew, managed CLI, native bundle, vendor and Steam adapters have separate effects injected for testing. Scanners remain read-only. The existing management session preserves ordering and stops after critical failures.

MacPorts configuration/library/executable ancestors must be root-owned and non-writable by other users. The helper takes only an encoded exact port/version request with bound executable/state fingerprints, age and single-use UUID. It has no arbitrary command, filesystem deletion, password or process-control RPC. It verifies the calling app’s signing identity/team, reconstructs the fixed standard MacPorts target, repeats preflight and protects the actual caller bundle. Request and XPC waits are bounded. Disconnect/cancellation/timeout never imply rollback or success.

A root-owned MacPorts installation requires a correctly packaged Apple-anchored signed app and matching-team helper. `SMAppService.daemon` is reached only after explicit confirmation. If macOS requires approval, the UI opens Login Items, reports **Waiting for User**, submits no uninstall, and requires a fresh preview afterwards. Approval registers a background helper; the preview discloses that persistent permission and where it can be revoked. No helper was registered, launched or approved in QA.

The project generator embeds the helper executable and LaunchDaemons plist; SwiftPM embeds helper identity metadata. Local packaging still defaults to ad-hoc signing. Therefore the default local bundle honestly offers Guided Only for a root-owned MacPorts registry. A distribution build needs the matching real signing team and separately validated Service Management deployment. Paid signing is not required for inventory or nonprivileged bundle/manager workflows; it is a prerequisite for this privileged route.

Nix removal validates executable ownership (including official sticky `nixbld` store permissions), modern profile mode, exact user-owned slot/generation links, version and all element records. It never passes a resolved immutable store generation as a mutable profile. Declarative/system and unsupported legacy profiles stay guided.

Native removal repeats fresh full manager-ownership review, containment, ownership/mode, bundle/executable/parent fingerprint, symlink, protection, service and running-process checks. Simulated eligibility cannot reach the live native effect. Finder must return the selected URL’s Trash mapping; independent postflight still checks original-path absence. The fixture effect uses only a recoverable rename inside a dedicated test tree; it never calls Finder or actual Trash.

Vendor association requires valid Apple-anchored signing chains and equal signing team for target/tool. Matching team establishes publisher association, not a universal guarantee of one-product scope. The preview tells the user to review the vendor tool’s choices. Discovery is bounded to relevant embedded/dedicated locations. No universal vendor script is trusted. Docker’s documented noninteractive uninstall was investigated but is not adopted as a generic safe default because its documented scope destroys containers/images/volumes; no Docker-specific special case or silent data-destroying CLI was added.

## Executed validation

- **207 Swift tests in 23 suites passed**, including opt-in read-only real-machine integration. Latest run: approximately 1.2 seconds of test execution, excluding build. Source parameter cases add more scenarios than the displayed test-function count.
- Full SwiftPM build passed for the app, core, InventoryVerify and privileged helper. Project regeneration, project/helper plist validation, build-script syntax, UI-test Swift syntax parsing and whitespace checks passed. Toolchain warnings concern SwiftPM’s deprecated native build-system selector and the Testing framework’s deployment version; no failing check remains in the recorded final run.
- Native GUI review used only `build/Execution Levels QA.app` with a unique identifier and persistent QA flags. Direct orphan, Interactive vendor, Guided incomplete Steam and Protected previews were inspected; checkbox gating, Cancel/Escape, OK dismissal and interactive verification were exercised. Result formatting and simulated interactive waiting were corrected after the first review; final screenshots are in `artifacts/execution-levels/`.
- Full **XCUITest was not run**. Only Command Line Tools are selected; full Xcode is unavailable. The new explicit-level/verification test is added and syntax parsed. No remote CI was dispatched, because no push/publication was authorized.
- Read-only live benchmark found 83 inventory records before launching the extra QA bundle; all source reports completed/empty/not-installed, with no failed report. For 1,000 synthetic cached rows over 25 runs, mean filter/name-sort was **3.67 ms** (max 3.98 ms); filter/health-sort **7.40 ms** (max 8.10 ms). Peak diagnostic resident memory was about **137.5 MB**. This measures the inventory diagnostic, not whole-app launch or manager-operation latency.

The extended cask check initially exposed a rejected `..` target and two legitimate absolute binary sources in live receipts. Parent targeting is now rejected; absolute binary source discovery works, while removal still validates the installed link’s exact ownership scope and separate hooks. The final live suite passes. A preexisting cancellation timing test was made deterministic with a continuation gate, preserving cancellation assertions rather than relaxing them.

Tests cover missing app/current registration, retained historical receipts, stale scan replacement, distinct physical copies, formula/CLI-only packages, multi-prefix conflicts, changed executable/profile/receipt, dependents/services, confirmation reuse/reentrancy/cancellation, permission/timeout/query failures, unknown/partial outcomes, failed-manager no-fallback, native callback without absence, vendor precedence, Steam duplicates and unrelated manager state/data preservation. The nui-app receipt/path regression remains generic: existing unusual-path bundles remain active; absent recorded payload becomes historical; a different physical copy is not merged by name or bundle ID. No production nui special case exists.

**No real installed app, package, manager state, real process or personal data was removed, moved, modified, reset or Force Quit during QA.** Only created fixtures and the disposable QA app were changed. Live queries only read inventory. Real provider uninstall, native Trash, signed-helper authentication/registration, vendor wizard and Steam completion need a separately authorized disposable environment. Passing mock-boundary tests does not establish those real integrations are release-validated.

## Changed files and review

New implementation files include `UninstallLevels`, `UninstallPreparation`, `UninstallExecutionService`, `ManagedRemoval`, `MacPortsAuthorization`, `BundleRemovalAdapter`, `VendorRemovalAdapter`, `InteractiveRemoval` and `CaskArtifactMapping`; a new privileged helper target and two helper plists; and `UninstallExecutionTests`. Existing changes extend scanners/typed queries, Homebrew and standalone boundaries, health/protection, vendor discovery, management UI/model, deterministic workflow tests, project generation and packaging. The complete 56-file tracked/untracked inventory is appended below. Ignored QA binaries/logs/screenshots are local evidence, not release assets.

All changes remain uncommitted. The preexisting 38 staged paths remain staged; continuation edits and new files are not staged. Proposed commit message, for later approval: `feat: complete unified source-aware uninstall execution`.

## Official references and research limits

- [Homebrew command options](https://docs.brew.sh/Manpage) and [cask artifact/effect contracts](https://docs.brew.sh/Cask-Cookbook). Arbitrary Ruby/shell uninstall directives are not treated as safe declarative file mappings.
- [MacPorts uninstall](https://man.macports.org/port-uninstall.1.html) and [dependents](https://man.macports.org/port-dependents.1.html).
- [Nix 2.34 profile removal](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-profile-remove.html). The implementation deliberately limits supported version/mode rather than guessing across formats.
- [Apple Service Management](https://developer.apple.com/documentation/servicemanagement/smappservice) and [updating helper executables](https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos).
- [Apple app removal](https://support.apple.com/102610), [native recycle](https://developer.apple.com/documentation/appkit/nsworkspace/recycle(_:completionhandler:)).
- [Setapp management instructions](https://setapp.com/how-to/5-tips-to-get-started-with-setapp), [JetBrains uninstall](https://www.jetbrains.com/help/idea/uninstall.html) and [Toolbox installation options](https://www.jetbrains.com/help/toolbox-app/installation.html). No reviewed macOS exact-target uninstall integration was found; that finding is bounded to reviewed public docs.
- [Steam Browser Protocol reference](https://developer.valvesoftware.com/wiki/Steam_browser_protocol). This primary page was blocked by anti-bot protection during current revalidation. No challenge was solved or bypassed. The known protocol handoff is implemented/tested at an injected opener boundary; current official-page and disposable macOS validation remain outstanding.
- [Docker uninstall scope](https://docs.docker.com/desktop/uninstall/), reviewed to avoid silently adopting a data-destroying generic vendor CLI.

## Working file inventory

- `Docs/ARCHITECTURE.md`
- `Docs/SOURCE_SUPPORT.md`
- `Docs/UNIFIED_UNINSTALL_AND_HEALTH.md`
- `Docs/UNINSTALL.md`
- `Macventory.xcodeproj/project.pbxproj`
- `Package.swift`
- `README.md`
- `SECURITY.md`
- `Sources/InventoryVerify/main.swift`
- `Sources/Macventory/AppModel.swift`
- `Sources/Macventory/DetailsView.swift`
- `Sources/Macventory/InventoryTable.swift`
- `Sources/Macventory/InventoryView.swift`
- `Sources/Macventory/ManagementView.swift`
- `Sources/Macventory/UninstallView.swift`
- `Sources/MacventoryCore/AppDataSafety.swift`
- `Sources/MacventoryCore/Domain.swift`
- `Sources/MacventoryCore/HomebrewRemovalAdapter.swift`
- `Sources/MacventoryCore/HomebrewScanner.swift`
- `Sources/MacventoryCore/HomebrewTrust.swift`
- `Sources/MacventoryCore/InstallationHealth.swift`
- `Sources/MacventoryCore/InventoryCategorySelection.swift`
- `Sources/MacventoryCore/InventoryService.swift`
- `Sources/MacventoryCore/InventorySort.swift`
- `Sources/MacventoryCore/ManagementWorkflow.swift`
- `Sources/MacventoryCore/ManifestScanners.swift`
- `Sources/MacventoryCore/NativeScanner.swift`
- `Sources/MacventoryCore/OfficialRemovalDocumentation.swift`
- `Sources/MacventoryCore/PackageScanners.swift`
- `Sources/MacventoryCore/ProcessRunner.swift`
- `Sources/MacventoryCore/SourceRemovalGuide.swift`
- `Sources/MacventoryCore/StandaloneRemoval.swift`
- `Sources/MacventoryCore/Uninstall.swift`
- `Sources/MacventoryCore/VendorUninstaller.swift`
- `Tests/MacventoryCoreTests/InstallationHealthTests.swift`
- `Tests/MacventoryCoreTests/InventoryTests.swift`
- `Tests/MacventoryCoreTests/ManagementWorkflowTests.swift`
- `Tests/MacventoryCoreTests/ToolboxModernTests.swift`
- `Tests/MacventoryCoreTests/UninstallTests.swift`
- `UITests/MacventoryUITests.swift`
- `scripts/build-app.sh`
- `scripts/generate-project.py`
- `Docs/UNINSTALL_EXECUTION_LEVELS.md`
- `Resources/Helpers/MacventoryPrivilegedHelper-Info.plist`
- `Resources/Helpers/org.vadimtanel.Macventory.macports-helper.plist`
- `Sources/MacventoryCore/BundleRemovalAdapter.swift`
- `Sources/MacventoryCore/CaskArtifactMapping.swift`
- `Sources/MacventoryCore/InteractiveRemoval.swift`
- `Sources/MacventoryCore/MacPortsAuthorization.swift`
- `Sources/MacventoryCore/ManagedRemoval.swift`
- `Sources/MacventoryCore/UninstallExecutionService.swift`
- `Sources/MacventoryCore/UninstallLevels.swift`
- `Sources/MacventoryCore/UninstallPreparation.swift`
- `Sources/MacventoryCore/VendorRemovalAdapter.swift`
- `Sources/MacventoryPrivilegedHelper/main.swift`
- `Tests/MacventoryCoreTests/UninstallExecutionTests.swift`

## Local QA evidence

- [Direct level](../artifacts/execution-levels/direct-level.png) and [unchecked confirmation](../artifacts/execution-levels/direct-preview.png).
- [Interactive level](../artifacts/execution-levels/interactive-level.png) and [waiting result](../artifacts/execution-levels/interactive-waiting.png).
- [Guided level](../artifacts/execution-levels/guided-level.png) and [blocked level](../artifacts/execution-levels/blocked-level.png).
- [Final tests](../artifacts/execution-levels/final-tests.log), [final build](../artifacts/execution-levels/final-build.log), [read-only benchmark](../artifacts/execution-levels/live-benchmark.log).

These ignored local artifacts are available in this checkout and are not committed documentation assets.
