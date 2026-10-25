# Unified uninstall and inventory health — implementation and QA report

**Earlier-pass report:** [Uninstall execution levels](UNINSTALL_EXECUTION_LEVELS.md) supersedes this report’s source-removal limits and test totals. MacPorts, modern mutable Nix profiles, Steam handoff and limited PKG bundle removal now have production adapters.

Branch: `feature/unified-uninstall-and-inventory-health`. Baseline: `22334cd`.
Validation date: 24 October 2026. This is development work, not a release announcement.

## Root causes and read-only findings

### Missing Homebrew application

The previous Homebrew scanner read Caskroom receipts, skipped declared app artifacts that did not exist, and fell back to a generic package row. That fallback used the Caskroom path as its package identifier instead of preserving the installed cask token. Consequently a retained installer record could appear after manual app deletion without explaining the mismatch. The planner then required every source to have an existing top-level `.app` before considering its manager. A package record could never reach the Homebrew strategy. The old bundle-ID-wide Macventory prohibition also confused separate builds with the selected installation.

Discovery now preserves the exact token, Homebrew executable/prefix, receipt, expected app paths, observed presence and manager registration separately. Homebrew's installed listing is queried once per prefix/source. A missing declared app with a current installed token is **Application Missing — Homebrew Registration Remains**, represented as a managed package with no false app path. A receipt alone is not an installed-state query. Missing/unreadable manager state is unverified; metadata left after a verified absent token is historical.

The regression uses synthetic token `macventory`, version `1.0.0`, a missing application, retained Caskroom metadata and a separate development-copy location. Production code contains no token-specific exception. On this machine at verification time, neither standard Homebrew prefix contained a `macventory` Caskroom entry and `/Applications/Macventory.app` was absent. The original reported mismatch was therefore reproduced synthetically, not claimed to be present in today's live inventory.

**Homebrew missing-artifact limitation:** normal uninstall is not guaranteed to reconcile this condition. The installed Homebrew `Moved#move_back` implementation first checks its source and raises when the target is absent unless special handling is requested. Macventory can attempt only the reviewed normal official operation. It does not retry with force, zap, cleanup, dependency overrides or metadata editing. Failure/partial state remains visible with an official guided recovery path. The successful fake-manager regression establishes orchestration and reconciliation behavior, not that this Homebrew version can remove every orphan without force.

References: [official uninstall options](https://docs.brew.sh/Manpage), [cask artifact implementation interface](https://docs.brew.sh/rubydoc/Cask/Artifact/Moved.html), [uninstall effects](https://docs.brew.sh/Cask-Cookbook#stanza-uninstall).

### nui-app

The PKG receipt's installation root is `Users/runner/work/nui/nui/./build/bin` on volume `/`. The actual receipt ID is `com.wails.nui-app`, version `1.0.0`. Read-only filesystem inspection confirmed the recorded build copy’s `Contents/Info.plist` and its `Contents/MacOS/nui-app` executable currently exist. `/Applications/nui-app.app` was absent. The new live scan therefore correctly retains one PKG application at the build-looking path. Its appearance alone does not make it a stale receipt.

The merger uses physical canonical paths, not names or bundle identifiers. Two actual nui copies remain two installations. Deleting the Applications copy does not delete the separate receipt payload. If the recorded build path is absent, the receipt becomes a historical package record; it cannot establish an active GUI application. An incomplete scan retains explicitly stale/unverified observations instead of declaring disappearance. Synthetic tests cover separate physical copies, historical records and stale-observation replacement. Receipt presence alone never authorizes `pkgutil --forget` or payload deletion.

## Architecture and workflow

- `InstallationHealth.swift`: Codable health, registration and artifact observations; source-aware classification; protected locations and exact running-bundle comparison. `lstat`/ancestor access checks distinguish absence, broken links and denial. UI health reads use stored observations rather than repeatedly traversing filesystems during sorting.
- `HomebrewScanner.swift` / typed `InventoryCommand`: bounded receipt parsing plus batched installed-state queries. Tokens, versions, custom app directories and `target` renames remain distinct from native app metadata. A staged Caskroom bundle cannot substitute for a missing declared app target. Existing keg/link metadata is retained.
- `PackageScanners.swift`, `NativeScanner.swift`, `ManifestScanners.swift`: historical PKG evidence, malformed bundles/missing executables, MacPorts expected app artifacts, missing Nix store objects, Steam manifests without payload, and unverified Toolbox launcher references. No `.app` requirement is imposed on legitimate CLI/profile packages. Setapp does not expose an authenticated registration adapter here.
- `InventoryMerger` / `InventoryService` / `SnapshotStore`: canonical-path identity, separate copies, ownership conflicts including different Homebrew prefixes, source-specific replacement, stale retention on failure, and replacement of a stale observation by a fresh observation with the same identity. Optional health storage preserves old snapshot decoding; loaded snapshots remain stale until scanned.
- `UninstallPlanner`: immutable source-specific plans. Manager eligibility precedes bundle-only eligibility. Native recoverable Trash remains limited removal. External provider guidance is centralized in `SourceRemovalGuide`.
- `FreshUninstallValidator` / `UninstallSession` / `ManagementSession`: fresh manager identity, exact installed version, receipt/configuration/executable/artifact fingerprints, ownership, process/self protection, expiry and single-use confirmation. Formula dependents and multiple installed versions block automatic removal. Cask manager version is separate from a self-updated app version.
- `HomebrewRemovalAdapter`: dependency-injected official manager operation followed by independent manager and expected-artifact checks. Exit zero alone is not success. Known remaining payload, failed re-query, interruption and absent registration have distinct outcomes.
- `VendorUninstallerDiscovery`: bounded local candidate discovery; valid Apple-anchored code-signing chains and equal signing team establish publisher association. Names only locate candidates. Both target and tool are fingerprinted and checked again. Production launch uses native macOS application launch, returns **Waiting for User**, and never treats launch as removal.
- `OfficialRemovalDocumentation`: fixed HTTPS provider destinations, explicit user action, ephemeral HEAD resolution and same-provider redirect validation. Pages are instructions for the user, never command sources.

The workflow is scan → classify → inspect source/health evidence → prepare immutable scope → acknowledge → freshly validate → execute or guide → independently verify → display precise result → refresh source and filesystem observations after dismissing the result. Existing Leftover Data review remains a separate, optional, individually confirmed workflow. No discovery, repair or reinstall changes installation state automatically.

Outcomes distinguish verified manager-and-artifact removal, registration removal, bundle-only removal, remaining data, waiting for user, partial removal, already absent, blocked, failed, unknown and simulation. These do not assert removal of every file ever created by third-party software.

## Source support and validation matrix

“Simulated” means fake executors and isolated synthetic data; it is not destructive provider validation. Native production removal adapters were not executed during QA.

| Source | Detection and health | Normal removal | Orphan handling | Vendor handoff / bundle fallback | Validation and limits |
|---|---|---|---|---|---|
| Homebrew Cask | Exact receipts/config targets plus installed tokens, per prefix; missing app, historical metadata, unverified query and existing payload distinguished | Official normal uninstall for one exact mapped app; reviewed exact-ID declarative quit supported; scripts/services/additional effects receive guided review | Missing app does not block manager preview. Attempt normal operation; independently check registration/artifacts. Failed reconciliation stays unresolved | Official Homebrew recovery guidance; no filesystem fallback | Synthetic healthy/orphan E2E and contract tests; real discovery/query/repeated scans read-only. Missing-artifact normal uninstall can fail in real Homebrew. No forced reconciliation implemented |
| Homebrew Formula | Keg/version and installed token; CLI-only state valid | Official formula uninstall; exact single installed version and no installed dependents required | Manager queries and remaining keg checks distinguish partial/absent state | Homebrew guidance if identity, versions, dependencies or trust cannot be established; no direct keg deletion | Mock execution/verification, live read-only inventory. Custom manager locations are guided. External consumers/services may be affected by removal; no universal runtime-impact analysis |
| PKG | Receipt event plus existing exact app payload; absent/unmapped payload remains historical or unverified | Matching trusted local vendor Uninstaller.app, when discoverable; interactive scope review | Historical receipts remain informational; no forget/delete operation | Signed vendor handoff; generic Apple removal reference and vendor review otherwise; no automated PKG bundle fallback | Receipt/parser/nui fixtures and real receipt/payload inspection. Signing association mocked; real unsigned fixtures rejected. No real vendor uninstaller launched |
| Mac App Store | Local receipt evidence remains inferred; physical/protection checks separate | Native recoverable bundle Trash only after valid signed bundle, local receipt, ownership, standalone/service checks; otherwise documented Finder guidance | Missing native observations reconcile on fresh scan; no purchase-record cleanup | Apple native workflow; preserves purchases, subscriptions and documents | Negative signature/marker and standalone safety tests; no real Store purchase/receipt or Trash execution validated |
| MacPorts | Installed version/variants plus contents; missing app artifacts retained; CLI packages stay valid | Guided official port uninstall after reviewing exact version/variants, prefix and dependents | Broken package evidence remains visible; external manager reconciliation | No direct prefix/file deletion | Parser/contents/CLI/missing-app fixtures; manager absent locally. Privileged and dependent-removal workflows not automated |
| Nix | Modern current-user profile JSON, legacy query fallback; missing referenced store paths retained | Guided exact profile-element removal | Missing files flag attention; declarative/uncertain profile ownership stays guided | No store deletion or garbage collection | Modern/legacy/missing-path fixtures; Nix absent locally. Arbitrary profiles and declarative closure editing unsupported |
| Setapp | Provider roots plus embedded framework, inferred association | Guided Setapp app-only removal options | Registration absence cannot be authenticated; failed observations stay unverified | No directory deletion fallback; use Setapp | Existing provider fixtures and source-guidance contracts; no live account/provider test |
| Steam | Exact local App ID/library manifest; missing game payload remains a package-level warning | Guided Steam Library → exact game → Manage → Uninstall | Manifest without payload retained; refresh after external completion | No manual library deletion | Synthetic manifest/payload/guidance tests; Steam absent locally. Saves/shared data remain outside automatic removal |
| JetBrains Toolbox | Legacy layout plus generated-launcher exact target; stale target becomes unverified provider reference | Guided Toolbox action for exact IDE/version/path | Do not assert active Toolbox registration from a launcher alone | No managed-directory deletion | Existing legacy/modern/spoofed launcher tests plus new stale-reference assertions; no live Toolbox removal |
| Direct / Unmanaged | Bounded native bundle metadata, executable and protection observations | Trusted vendor tool first; otherwise freshly audited, eligible standalone bundle to native Trash | Removed bundles disappear after successful scans; failed scans preserve stale evidence | Bundle-only scope is explicitly incomplete; embedded/signed vendor discovery is bounded | Synthetic standalone/session/signing/identity tests; no real Trash or vendor execution |
| Unknown / conflicting | Conflicting sources/prefixes or incomplete ownership produce neutral unverified state | Blocked until ownership is resolved | Refresh/review evidence; no guessed command | No bundle deletion fallback | Conflict, incomplete-scan, injection and stale-state tests |

Official references: [Apple native removal](https://support.apple.com/102610), [MacPorts uninstall](https://guide.macports.org/#using.port.uninstall), [Nix profile remove](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-remove.html), [JetBrains IDE removal](https://www.jetbrains.com/help/idea/uninstall.html), [Setapp support](https://support.setapp.com/), [Steam support](https://help.steampowered.com/).

## Protection and trust model

System/sealed paths and actual filesystem removal restrictions remain protected. An Apple bundle identifier alone does not assign red/system status. The running Macventory bundle is protected by its actual path; a missing Homebrew installation is distinct from a different development build. Cask hooks that might quit another copy with the same bundle ID are blocked while any matching copy runs. Process/data safety stays independent of package-level eligibility.

Homebrew production queries/execution accept owner-controlled standard executable locations with no world-writable path components. Group-writable components are accepted only for administrative `admin`/`wheel` groups. The script bytes/inode are fingerprinted. Other prefixes remain discoverable through receipts but require external review for execution. This is a local installation trust boundary, not cryptographic proof that every Homebrew recipe is benign.

Only structured executable/argument arrays reach Process. No shell command string, arbitrary script download, automatic privilege escalation, password collection, SIP/Gatekeeper changes, generic force-delete mode, zap, cleanup, dependency override, store GC or manual manager metadata editing is present in this feature. Metadata reads and source queries are bounded; concurrent filesystem/manager changes cannot be made perfectly atomic across external tools. Final checks reduce this residual race and failures never imply rollback.

Vendor discovery searches embedded Helpers/Resources and a dedicated containing vendor folder, with bounded candidate counts. It deliberately does not scan every app in Applications for same-publisher uninstallers or trust arbitrary downloaded/unsigned helpers. Matching signing teams establish publisher association, not a guarantee that the interactive tool removes only one product. Its scope must still be reviewed by the user. Arbitrary documented shell uninstall commands and a universal vendor catalog are unsupported.

## UI and accessibility

The compact **Status** column is sortable and customizable, with icon, semantic accessibility label/value and evidence tooltip. Healthy rows use subdued green; attention/partial use amber; protected uses red; unverified/historical use neutral symbols. There are no warning-colored row backgrounds. Details and management show expected and observed paths, manager ID/state, evidence and last verification time. The Attention Required Smart View includes actionable inconsistencies and partial states; the filter exposes every status.

Management preserves its review acknowledgment and single-use confirmation. Orphaned packages can show **Remove Orphaned Installation** without enabling app-data or process operations that lack identity. Unsupported mechanisms show specific official guidance. Protected targets have disabled removal. Terminal outcomes have an operable OK button; inventory refresh follows dismissal, including failed/partial attempts. A vendor handoff is waiting for user completion, not success.

Local screenshots are intentionally ignored QA artifacts, not release assets:

- `artifacts/unified-health/health-overview.png`: synthetic Light Mode inventory.
- `artifacts/unified-health/health-dark.png`: synthetic Dark Mode inventory.
- `artifacts/unified-health/orphan-management.png`: missing cask evidence and enabled remediation.
- `artifacts/unified-health/simulated-result.png`: explicit simulation and working OK action.
- `artifacts/unified-health/protected-management.png`: protected component with disabled removal.

Actual native GUI checks exercised the Smart View, status header sorting, protected-status filtering, orphan preview, disabled-before-review confirmation, simulated execution, result dismissal, Light/Dark appearance and protected blocking. The AX tree exposed descriptive health labels and values. Full VoiceOver navigation, all window sizes, all keyboard paths, every provider dialog and full XCUITest execution remain unverified.

## Test and performance evidence

See the final command results in the delivery notes below. Tests cover old snapshot decoding; source/health filters and sorting; stale replacement; exact cask identity and target renames; custom directories; access denial/broken links; CLI-only packages; missing cask/Nix/MacPorts/Steam payload; historical PKG and nui copies; self-location distinction; cross-prefix conflicts; trusted vendor association/unsigned rejection; documentation redirect policy; single-use confirmation; manager replacement; formula dependents; hook effect review; success/partial/unknown results; permission/authentication/timeout/cancellation failures. Existing process and leftover-data suites remain active.

The orphan E2E uses a stateful fake manager: discover → classify → plan → reject absent acknowledgment → confirm once → change synthetic registry → verify → rescan → historical metadata without a false active app. Another synthetic E2E removes only disposable fixture payload/metadata while retaining a separate copy and personal-data fixture. Neither invokes Homebrew or a native removal executor.

Read-only real integration checks compare native metadata and Homebrew ownership and repeat full scans without duplicate/stale identities. The diagnostic inventory contains 81 records, including 56 formula and 6 cask discoveries before cross-source merging. A representative scan took approximately 0.75 seconds. A later 1,000-row cached filter/sort probe over 25 repetitions averaged 3.70 ms by name and 7.64 ms by status (maximum 9.51 ms); diagnostic peak resident memory was 137,084,928 bytes. These are one-machine observations, not a controlled baseline overhead study or a worst-case inventory guarantee. Manager querying is batched by source/prefix; destructive preflight intentionally queries again.

No real app/package, user data, actual manager registry or receipt was removed, repaired, reset, moved or Force Quit. The existing installation was not a removal, repair, cleanup or Force Quit target. QA used a separate uniquely identified, persistent simulation-only app. No published binary, DMG, ZIP, release tag or Homebrew distribution was changed.

## Remaining validation and unsupported behavior

- Real destructive Homebrew, native Trash, signed vendor and Store removal require an explicitly authorized disposable environment. Normal Homebrew missing-target failure is known; a universally successful non-force reconciliation is not claimed.
- MacPorts, Nix, Setapp, Steam and Toolbox use guided provider workflows; this branch does not claim an automated executor or authenticated registration API for those sources.
- Arbitrary PKG vendors, external standalone uninstall scripts, undocumented helper layouts and complete cleanup of every third-party file are unsupported.
- Custom Homebrew executable trust, multi-artifact/privileged cask automation and automatic formula service-impact analysis require further work. The safe fallback remains guided review.
- Vendor completion needs the user to refresh; launch alone cannot establish its result. No universal waiting/monitoring API is invented.
- A full Xcode installation is absent locally. The Xcode project was regenerated and plist-validated; the added XCUITest is not claimed compiled or executed. Full VoiceOver, resize and keyboard audits remain pending.
- Partial outcomes are explicit in the operation result; fresh inventory derives current mismatch evidence. A durable cross-launch journal of unfinished external uninstall operations is not implemented.

## Git and delivery boundaries

The exact requested branch already existed and was checked out with a clean worktree at task start. It contains the pre-existing icon/Caskroom fix above local main `87de37f`; that baseline was preserved. The earlier application-management branch remains intact. No unrelated merge, rebase or reset was performed. The user-referenced `BOOST.md` was absent from the repository and its checked parent directories; no hidden instructions were inferred.

All feature changes remain unstaged/uncommitted. No commit, push, merge, tag, public release or distribution update is authorized or performed. Proposed commit message:

`feat: unify source-aware uninstall and installation health`

## Final command results

- `MACVENTORY_DISABLE_SWIFTPM_SANDBOX=1 MACVENTORY_LIVE_TESTS=1 bash scripts/swift-tool.sh test`: **PASS — 184 tests in 22 suites, 1.142 seconds test execution**, including the three opt-in read-only real-machine tests. No production removal executor is called by these tests.
- `MACVENTORY_DISABLE_SWIFTPM_SANDBOX=1 bash scripts/swift-tool.sh build --product Macventory`: **PASS** for the final source.
- `python3 scripts/generate-project.py` and `plutil -lint Macventory.xcodeproj/project.pbxproj`: **PASS**.
- `git diff --check`: **PASS**.
- Native GUI smoke: **PASS for the exercised synthetic flows** listed above. Final build also verified the enabled orphan action, exact manager-registration scope, acknowledgment gating and Escape cancellation. The separate QA app was quit normally.
- Full XCUITest compile/run: **NOT RUN — full Xcode unavailable**. A source test was added; syntax parsing alone is not treated as execution.
- Local evidence logs: `artifacts/unified-health/tests.log`, `build.log`, `read-only-scan.log`, and `read-only-integration.log`. These ignored local artifacts are not publication assets.

The CLT helper disables SwiftPM's nested build sandbox because the enclosing restricted environment cannot create that nested sandbox. Filesystem/tool access restrictions remain in force. Existing native-build-system deprecation and test-framework deployment-target warnings remain visible; tests actually ran on the current macOS.

## Changed files at delivery

- `Docs/ARCHITECTURE.md`
- `Docs/SOURCE_SUPPORT.md`
- `Docs/UNIFIED_UNINSTALL_AND_HEALTH.md`
- `Docs/UNINSTALL.md`
- `Macventory.xcodeproj/project.pbxproj`
- `README.md`
- `SECURITY.md`
- `Sources/InventoryVerify/main.swift`
- `Sources/Macventory/AppModel.swift`
- `Sources/Macventory/DetailsView.swift`
- `Sources/Macventory/InventoryTable.swift`
- `Sources/Macventory/InventoryView.swift`
- `Sources/Macventory/ManagementView.swift`
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

38 changed/new source, test, project and documentation files; none staged. Generated local QA bundles, fixture trees and screenshots are ignored. No release resources or distribution workflows were changed.
