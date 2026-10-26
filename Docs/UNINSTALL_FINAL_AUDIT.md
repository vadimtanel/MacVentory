# Final independent uninstall audit

Audit date: **25 October 2026**, Asia/Jerusalem. Recommendation: **COMMIT READY for the feature branch after review; not release ready.**

## A. Executive summary

The original 207 passing tests did not establish correctness. Independent code review found material defects in authorization, target binding, native launch identity, vendor association, result reconciliation and publication validation. Those verified defects are fixed in the working tree, with new or extended regressions. The final combined Swift run passes **221 tests in 24 suites**, including three opt-in, read-only real-machine integration tests. Debug and optimized builds pass. No real removal or privileged-service activation was performed.

Repository inspection found an important difference from the brief: the feature was **already committed** as `7422449068ed0dc82638598a8266d34be0e5c056` (`feat: complete unified source-aware uninstall execution`). The worktree and index were clean at audit start. The complete feature was therefore reviewed against parent baseline `22334cd`, followed by the combined audit fixes against the existing feature commit. No commit or index changes were made by this audit.

The recommendation permits recording the reviewed implementation and fixes on the feature branch. It does **not** certify privileged deployment, notarization, actual external-provider behavior, minimum-OS runtime behavior, full Xcode compilation or XCUITest. Those release gates are listed below. The existing feature commit must not be released without these audit fixes.

Three isolated read-only subreviews were requested for security, macOS/packaging and QA/UI. Their concrete findings were checked against the actual source and reconciled here; their preliminary conclusions were not accepted as a substitute for validation. The referenced `BOOST.md` instruction file was absent from the repository and its ancestor directories. No unrelated repository instructions were imported.

## B. Security and correctness findings

Locations refer to the current files/functions; line numbers identify the main fix, not every affected statement. All findings below are fixed unless marked as a remaining limitation.

| ID / severity | Affected location | Evidence / reproduction | Consequence | Implemented fix and regression |
|---|---|---|---|---|
| F01 **High** | `Sources/MacventoryCore/MacPortsAuthorization.swift:107`, `:125`, helper `main.swift` connection acceptance | Previously the daemon accepted requests based on app/team identity and Service Management approval alone; there was no Authorization Services right check | Another local user running the genuine signed app could request a system-wide port removal through an already-approved daemon without administrative authorization | A fresh client authorization session requests the system administrator right after confirmation. The external form is kept in memory, sent only to the authenticated helper, and its rights destroyed on completion. The helper checks the right without interaction before queries and immediately before the effect. Missing/malformed/denied authorization never reaches mutation. The OS may reuse valid credentials; this is not a promise of a password dialog every time. Tests inject grant/deny and exercise malformed-form rejection; no actual authorization dialog or service was invoked |
| F02 **High** | `Sources/MacventoryPrivilegedHelper/main.swift:8`, `MacPortsAuthorization.swift:78` | Caller identity was sampled by PID once; the client did not constrain the responding helper identity | PID-based trust could age, and authorization data could be sent to an unverified peer | Both connections now enforce an exact Apple-anchored identifier/team requirement using the macOS 13 XPC API before resume. Team/identifier strings are allowlisted and validated. Existing caller-path inspection remains for self-protection; it is no longer the only message-authentication boundary. Malformed identity tests added; real signed XPC deployment remains untested |
| F03 **High** | `Sources/MacventoryCore/Uninstall.swift:98` | Discover an orphan cask, change config appdir to a second same-named app, then prepare. Fresh mapping previously selected the new target while preview/fingerprint verification still used old scan artifact paths | The reviewed and actual affected copies could differ; postflight could verify the wrong path | All fresh mapping paths and presence observations must match discovery before preparing Direct. Changes require refresh and a new preview. Config/receipt bytes remain fingerprinted between review and execution. Tests cover redirected appdir and missing-to-present changes; the second copy stays intact |
| F04 **High** | `Sources/MacventoryCore/ManagedRemoval.swift:34`, `:174` | Replace a port-owned payload, or create a formerly absent payload, after confirmation while installed/contents text stays unchanged | Old confirmation could remove a different physical target, including through the helper | MacPorts state proof now includes all bounded registered paths' device/inode/type/owner/mode/size/nanosecond change times, canonical resolution and symlink destinations. Tests replace and create fixture payloads and assert no manager effect occurs. This narrows but cannot eliminate the final external-tool race |
| F05 **High** | `Sources/MacventoryCore/ManagedRemoval.swift:73–108` | A root-owned configuration/Tcl file can be replaced through a writable ancestor; POSIX mode checks alone also overlook ACL write grants | An unsafe MacPorts installation could load substituted code/configuration as root | Validate root ownership, modes, canonical paths and absence of extended ACLs for configuration/library/registry ancestors and executable ancestors; bind anchor contents to the executable proof. A real extended ACL is added only to a disposable fixture and detected by the regression. Darwin's empty-ACL behavior is handled explicitly. Benign extended ACLs may conservatively make this route unavailable |
| F06 **High** | `Sources/MacventoryCore/VendorUninstaller.swift:36`, `:85`; `InteractiveRemoval.swift` native opener | AppKit's `allowsRunningApplicationSubstitution` defaults to true, permitting another running physical copy | A verified tool/client URL did not guarantee the instance receiving a launch or uninstall URI | Native vendor/Steam opening disables substitution, then verifies the returned application's bundle URL. A pure AppKit configuration regression checks the prevention flag without launching any application. There is still a residual validation-to-open race |
| F07 **Medium** | `Sources/MacventoryCore/VendorUninstaller.swift:36–68` | Any nonstandard app parent was assumed to be a dedicated vendor directory; fingerprints bound only directory inode and Info.plist | A same-publisher sibling uninstaller for another product could be chosen; changed signed code could reuse a preview | Generic discovery is now confined to selected-app embedded locations. Target and tool proofs include executable bytes/identity and available CodeDirectory hash; production signing checks validate nested code too. Tests reject sibling association, accept matching embedded association, reject team mismatch and detect changed executable bytes. External vendor tools need an individually reviewed association contract |
| F08 **Medium** | `Sources/Macventory/ManagementView.swift:52`, `AppModel.swift:210` | OK remained enabled while verification awaited filesystem inspection; dismissal then called a cleanup method that returns while busy | Sheet could close while retaining management state, blocking later reviews | OK is disabled while working; interactive dismissal is already disabled. Verification is bound to the presentation/plan token. Manual GUI verification followed by OK and opening another review passed. The precise delayed real-filesystem timing case has not been exercised through XCUITest |
| F09 **Medium** | `Sources/MacventoryCore/ManagementWorkflow.swift:20–34`, `AppModel.swift:210` | Verify replaced a combined result with a one-step uninstall result, could verify an uninstall never invoked, and did not save newly verified removal history | Earlier process/data results disappeared or a skipped removal could look successful; leftover history was missing | Only waiting/partial/unknown uninstall steps are verifiable. Replace only that step, preserve other results, and record history only after verified completion in live mode. Tests preserve combined outcomes and reject skipped/completed verification; GUI confirms waiting and dismissal. Actual history writes after external removal are not destructively tested |
| F10 **Medium** | `Sources/MacventoryCore/InventoryService.swift:31–32` | Conflict comparison read `Profile`, while Nix discovery writes `Nix profile` | Same store output/element observed under different profiles could silently select one ownership record | Compare the actual profile field. New merge regression produces Unknown/Blocked. Current production enumeration is limited to one current-user profile; the test protects combined/future observations |
| F11 **Medium** | `Sources/MacventoryCore/InteractiveRemoval.swift:87–110` | Missing selected manifest/payload plus an index without an apps entry was previously enough for success, even if the same App ID had moved to another registered library | False removal verification | Inspect every registered library's manifest; disconnected/unavailable libraries produce unknown, remaining manifests produce partial. Limit targeted review to 128 libraries, and bind payload/manifest/index physical identity into preparation. Extended production-adapter fixture test covers moved and offline libraries |
| F12 **Medium** | `Sources/MacventoryCore/HomebrewRemovalAdapter.swift:33`, `:47` | Token-wide uninstall could broaden scope when multiple versions were installed; postflight did not compare unrelated registry entries | Broader removal scope or unrelated change could be reported as clean success | Multiple versions are rejected before mutation; unrelated installed tokens/versions must be unchanged afterwards or outcome is partial. Multi-version regression asserts zero effects; an unrelated-registry mutation regression returns partial despite exit zero |
| F13 **Low** | `Sources/MacventoryCore/HomebrewScanner.swift:77` | Absent registration plus nil app path always became historical, even if mapped font/binary payload remained | Retained payload was hidden from Attention Required | Historical override now requires all reviewed artifacts to be missing; retained-font regression stays attention and cannot authorize removal |
| F14 **Low** | `Tests/MacventoryCoreTests/UninstallTests.swift`, `GatedValidation` | Duplicate-confirmation test synchronized 100 ms validation against a 20 ms sleep | Scheduler-dependent false failure or missed reentrancy coverage | Replace delay coordination with a started/release continuation gate; duplicate and replacement requests are asserted while validation is provably suspended |
| F15 **Medium** | `scripts/package-release.sh:5`, `Docs/UNINSTALL_EXECUTION_LEVELS.md`, synthetic AppModel record | The publication checker rejects developer absolute paths and missing Markdown links. The feature added a literal machine-specific fixture path and links to ignored local evidence | Packaging failed locally; ignored links also failed in a clean runner and prevented the dependent UI job | Make the fixture path relative to its own root, describe historical locations without a developer-specific absolute path, and describe ignored evidence as local paths rather than repository links. Run publication preflight before packaging can overwrite any output. The unchanged checker now reports zero findings |
| F16 **High** | `Sources/MacventoryCore/HomebrewTrust.swift`, cask planning/fresh validation in `Uninstall.swift` | A binary-only cask may also contain a staged running app inside Caskroom; declared link artifacts alone do not cover the directory the manager removes | The active Macventory copy or another running staged app could be missed | Include the complete selected Caskroom root in self/running-process scope. Regression checks a staged running copy and an unrelated development copy |

Additional hardening rejects MacPorts expression operators (`not`, `and`, `or`, `xor`) as port names, preserves the bounded replay ledger while expiring old entries, and shows freshly prepared manager artifact observations in the preview. No command shell, arbitrary privileged RPC, downloaded script, password collection, force-delete mode or failure-to-deletion fallback was introduced.

### Authorization and deployment assessment

The privileged route is **implemented and compiled, not production-deployment certified**. Its XPC method accepts only an encoded exact port/version request, immutable fingerprints, age, UUID and authorization external form. It reconstructs the fixed standard prefix itself, rejects stale/duplicate requests, validates the caller and responding helper, and redoes source/payload/dependency/protection checks. It cannot accept an arbitrary executable, shell, flag array, filesystem-delete or process-control command.

Service Management approval grants persistent background-helper availability and remains separately disclosed/revocable in Login Items. It grants no authority for subsequent root removals. The daemon never prompts or expands rights. Cancellation, disconnect and timeout do not imply rollback; unknown results require rescan and a new review. Requests and waits are bounded. Replay records expire after the acceptance lifetime rather than permanently exhausting the daemon's capacity.

The trust model assumes a trustworthy installed package manager and its recipes/runtime. Checking root-controlled anchors is not a cryptographic audit of every MacPorts Tcl file, extension or dynamic dependency. An administrator who can change the privileged installation is already inside that trust boundary.

## C. Source coverage matrix

“Tested” below means real production planning/adapter logic with injected effect boundaries and isolated state unless explicitly described as live read-only. No row has real destructive provider validation on this Mac.

| Source | Levels and production mechanism | Independent verification | Automated coverage actually run | Real-world status / limitations |
|---|---|---|---|---|
| Homebrew Cask | **Direct** via `HomebrewRemovalAdapter`/normal `brew uninstall --cask -- token` for reviewed declarative app/font/owned-link mappings; **Guided** for unaudited effects; **Blocked** for changed/unsafe evidence | Token absent, expected artifacts absent, unrelated registry unchanged; exit zero insufficient | Healthy/orphan E2E, custom/renamed/multiple artifacts, target changes, hook review, multi-version rejection, fake executable, partial/query/interruption | Actual receipts and installed listing read safely. Read-only inspection of installed Homebrew `cask/artifact/moved.rb`, `move_back` confirms missing targets normally raise unless skip/force is selected. A normal attempt is not guaranteed repair. No force, zap, direct Caskroom deletion or retry fallback |
| Homebrew Formula | **Direct** normal `brew uninstall --formula -- token`; exact single version, no dependents or loaded/unverified service; otherwise **Guided/Blocked** | Registry, keg/artifacts and unrelated tokens rechecked | Scanner/CLI health, version/dependency/service blocks, production fake-effect verification and errors | Live keg discovery/query passed. No service shutdown, dependency override, autoremove, cleanup or complete external-consumer analysis |
| MacPorts | **Direct** `ManagedRemovalAdapter`: `port -N uninstall name @version_revision+variants`; per-request OS admin right and signed helper when root required; unsupported/unsafe cases **Guided/Blocked** | Exact installed version absent, other port identities unchanged, reviewed artifact sample absent; full registered path identity bound before execution | Scanner→plan→single-use confirmation→production fake effect→verification→rescan; variants, changed manager/dependencies/payload, permission/timeout/cancel/auth/partial/query failure; shared helper handler grant/deny tests | MacPorts absent locally. Standard prefix only; services/extensions excluded. Up to 64 CLI artifact observations are used after removal, not a full residual-filesystem audit. Actual root deployment/authorization remains a release gate |
| Nix | **Direct** exact named-element `nix --offline profile remove --profile slot -- element` for supported mutable current-user profiles; declarative/system/legacy/uncertain modes **Guided** | Selected element absent; full other-element records unchanged; valid mutable profile remains; store objects/generations remain | Production discovery/preparation/fake mutation/rescan, profile substitution, unsupported selectors/versions/modes, permission/cancel/timeout, unrelated metadata and profile conflict tests | Nix absent locally. Named manifest v3 and Nix 2.28–2.35 only. No store deletion/GC or declarative edits. No actual Nix mutation validated |
| PKG Installers | Trusted embedded vendor tool **Interactive**; otherwise separately eligible **Direct bundle-only Trash**; historical/unmapped/unsafe cases **Guided/Blocked** | Vendor launch waits; original bundle absence verified separately. Bundle adapter verifies absence; receipt intentionally remains historical | Synthetic receipt discovery→confirmation→production bundle adapter/fake move→historical rescan; vendor association/precedence; nui multiple-copy/receipt regressions | Real receipt/payload inspection is read-only. Never invert a receipt, delete all receipt paths or use forget as uninstall. No generic safe noninteractive vendor catalog |
| Mac App Store | Eligible signed bundles **Direct bundle-only Trash** through `BundleRemovalAdapter`; protected/ownership/signature failures **Guided/Blocked** | Original selected bundle absent, with purchases/account/external data outside removal scope | Positive fake receipt/signing case through confirmation and production fake effect/rescan; negative marker/signature/protected checks | Purchase/receipt cryptography is not authenticated. Real Store Trash not tested; no undocumented Store API |
| Steam | **Interactive** exact unique App ID URI in verified Valve client; missing/ambiguous evidence **Guided**; protection override **Blocked** | Launch waits; selected payload/manifest and manifests/index across all registered libraries checked; offline/partial remain honest | Production manifest discovery→confirmation→fake opener→waiting→synthetic state mutation→verification/rescan; duplicate/moved/offline libraries | No Steam installed. Actual macOS handoff and current primary protocol documentation revalidation remain pending; prior Valve page access encountered anti-bot protection. No challenge bypass or direct library deletion |
| Setapp | **Guided** exact app in documented Setapp UI; no trustworthy supported targeted uninstall handoff established | Rescan provider/native evidence; inferred framework association is not authenticated account state | Provider fixtures and explicit guidance/level selection; no removal executor falsely claimed | Provider absent. No guessed API/URL or deletion behind manager. Future integration requires reviewed official targeting contract |
| JetBrains Toolbox | **Guided** exact IDE/version/path inside Toolbox; unsafe/ambiguous evidence **Blocked** | New launcher/native observations after rescan | Legacy/modern launcher, spoof/dynamic/path/stale-target and guidance tests | Provider absent. No supported exact macOS removal CLI/deep link established; Windows install options are not used as a macOS uninstall contract |
| Direct / Unmanaged | Trusted embedded tool **Interactive first**; independently eligible **Direct recoverable Trash** otherwise; uncertain paths/ownership/services **Guided/Blocked** | Finder callback alone insufficient; original bundle absence checked. Vendor launch waits and only bundle absence is later asserted | Native discovery→review→single-use confirmation→production adapter with recoverable fixture rename→rescan; replacement symlink/callback/no-fallback/data-preservation tests | Actual Finder Trash/vendor launch not performed. Native standard or narrowly approved custom roots; no arbitrary-path deletion or external-data sweep |
| Unknown / conflicting / protected | **Blocked** override; no guessed executor | Refresh evidence; no action can be inferred from uncertainty | Cross-manager/profile conflicts, stale states, exact-copy self-protection and protected location tests; GUI blocked preview | Apple identifier alone does not make every Apple app protected. Filesystem restrictions and real running-copy path remain independent safeguards |

Read-only special-case reinspection confirmed that the recorded nui build copy still exists, its Info.plist passes native plist validation, and the Applications copy is absent. A build-looking location does not make that physical copy a stale receipt. The generic multiple-copy and receipt reconciliation fixtures pass; no real copy was moved or deleted and no production nui path is hardcoded.

The resolver is per installation, not a fixed source-wide level. The immutable plan and single-use session remain separate from health. Direct operation failure never invokes Trash or a second strategy. Leftover review is separate and opt-in.

## D. Validation results

| Check | Actual outcome |
|---|---|
| Baseline suite independently rerun before fixes | **207 tests / 23 suites passed**, with opt-in live read-only integration enabled. This did not suppress the findings above |
| Final unit/integration/synthetic E2E combined run | **221 tests / 24 suites passed**, no final failures; approximately **1.16 s** test execution excluding compilation. Parameterized scenarios exceed the displayed test-function count |
| Real-machine integration | All **3 opt-in read-only integration tests passed**: native payload/version, Homebrew ownership/kegs, repeated inventory reconciliation. These are included in 221, not additional destructive tests |
| Synthetic E2E | Included in the combined run: actual production adapters with fake manager registries, fake opener and recoverable fixture move; confirmation and post-removal rescans. No fabricated separate category total |
| Security regressions | Passed: redirected cask targets/presence, port payload substitution, missing/denied admin authority, malformed peer identities, extended ACL grant detection, exact launch configuration, embedded/sibling vendor association, changed executable, profile conflicts, moved/offline Steam verification, multi-version cask and deterministic confirmation gate |
| Debug build | **Passed** for app, core, InventoryVerify and helper; Swift 6 strict concurrency compilation |
| Optimized build | **Passed** using SwiftPM release configuration; this writes compiler outputs only, not distribution assets |
| Project and source checks | Generator rerun, all referenced SOURCE_ROOT files exist, project/helper plist lint, shell syntax, UI-test Swift syntax parse, diff whitespace checks passed |
| Local native GUI | Fresh separately identified QA app with persistent simulation flags. Light and Dark previews, all four levels, disabled confirmation, acknowledgment gating, Escape/Return/OK dismissal, reopening after verification, waiting result, Attention Required filter, Status sorting and native window zoom/resizing inspected. Only simulated effects |
| Accessibility | Semantic level/health labels and disabled control state inspected through native accessibility tree; basic Escape/Return navigation exercised. Full spoken VoiceOver navigation, every keyboard focus route and all display-size combinations **not run** |
| Full Xcode / XCUITest | **Not run locally**: only Command Line Tools, no full Xcode installation. Existing UI tests were syntax parsed, not compiled or passed. Hosted CI proposal below |
| Packaging | Fresh QA bundle including helper/plist and separate ZIP created and verified (ad-hoc deep/strict codesign and ZIP integrity). Publication-input checker passes. Existing production build/package/DMG scripts inspected but not executed because they replace versioned existing outputs |
| Gatekeeper / notarization / signed helper | **Not run**. Ad-hoc signature validation does not establish Developer ID trust or helper approval. No service registered, installed or launched |
| Performance | Read-only inventory benchmark: 83 records; no failed source report. 1,000 synthetic cached rows, 25 runs: name filter/sort mean **3.54 ms**, max **3.90 ms**; health mean **6.95 ms**, max **7.21 ms**. Peak diagnostic resident memory **137,150,464 bytes**. Not a whole-app or maximum-manager benchmark |

Intermediate audit runs exposed implementation/compiler mistakes while developing the fixes (Darwin ACL API typing/empty-ACL semantics and a shadowed function name); these were corrected. The final results above are from the subsequent passing run, not claims that every intermediate attempt passed. No test assertion was relaxed to conceal a failing security condition.

### Toolchain and compatibility

Local host: arm64 macOS 27.0.1, Apple Swift 6.4. Package language mode remains Swift 6, with minimum macOS **13.0**. Mach-O load commands for the debug app/helper confirm minimum 13.0; compiling on a newer host does not prove macOS 13 runtime correctness. `setCodeSigningRequirement` and Service Management APIs used here are available from macOS 13 in the installed SDK headers. The test tool wrapper raises the CLT testing host target to macOS 14 for the Testing framework.

The only persistent build-tool warning in the final build concerns SwiftPM's deprecated native build-system selector. There are no new source concurrency warnings. Intel execution and cross-build were not performed; published distribution tooling targets native arm64 and Intel is documented as optional. Full Xcode remains important because its generated project links a dynamic core framework whereas SwiftPM products use their package linkage.

### Hosted XCUITest investigation and exact proposal

`.github/workflows/ci.yml` has `workflow_dispatch`, read-only repository permissions, `macos-26` with explicitly pinned Xcode 26.5, native build/unit/package checks, and a dependent UI job using `--ui-testing` fixtures/simulation. It needs no workflow modification. `package.yml` is packaging, not the full GUI workflow. The GitHub connector returned no PR-triggered runs for the feature SHA; that endpoint is filtered and does **not** establish the absence of push/manual runs. The GitHub CLI is unavailable locally, and the available connector has no workflow-dispatch operation.

More importantly, **the final audit fixes are local and uncommitted**. Dispatching the old SHA cannot validate them, and its original publication inputs have the packaging defect above. No old workflow was rerun or pushed just to claim a GUI attempt.

After explicit approval to commit and push these fixes, the precise proposed verification is **Build and test Macventory / `.github/workflows/ci.yml` on `feature/unified-uninstall-and-inventory-health` at the newly approved SHA**. It runs native Swift/Xcode compilation, isolated unit tests, local-only packaging and synthetic XCUITest, uploading runner-produced verification artifacts (not local owner inventory). Standard CLI equivalent once available: `gh workflow run ci.yml --repo vadimtanel/MacVentory --ref feature/unified-uninstall-and-inventory-health`. Confirm the runner's pinned Xcode exists and inspect both job logs/results; a skipped or failed GUI job is not a pass. No workflow, remote ref, published asset or public Tap was modified in this audit.

## E. Changes made during this audit

| File | Audit change / regression relationship |
|---|---|
| `Sources/MacventoryCore/MacPortsAuthorization.swift` | Per-request OS administrator rights, authenticated responding peer, typed injectable authorizer and final effect gate; cancellation before service registration |
| `Sources/MacventoryPrivilegedHelper/main.swift` | Enforce caller requirement in XPC; bounded replay history expires old entries |
| `Sources/MacventoryCore/ManagedRemoval.swift` | Bind payload physical identities, reject expression operators, protect all trusted ancestors including ACLs, bind config/Tcl anchor bytes |
| `Sources/MacventoryCore/Uninstall.swift` | Reject fresh cask mappings/presence inconsistent with discovery |
| `Sources/MacventoryCore/HomebrewTrust.swift` | Share complete cask removal scope so staged running copies remain protected |
| `Sources/MacventoryCore/HomebrewRemovalAdapter.swift` | Reject multiple-version scope and verify unrelated registry preservation |
| `Sources/MacventoryCore/HomebrewScanner.swift` | Preserve attention for retained non-app artifacts without registration |
| `Sources/MacventoryCore/VendorUninstaller.swift` | Embedded-only product association, nested signing validation, target/tool executable and code-seal proof, exact native launch configuration |
| `Sources/MacventoryCore/InteractiveRemoval.swift` | Exact Steam client opening, payload identity, bounded all-library postflight and offline/retained-manifest outcomes |
| `Sources/MacventoryCore/InventoryService.swift` | Use actual Nix profile key when resolving conflicting ownership |
| `Sources/MacventoryCore/ManagementWorkflow.swift` | Pure interactive-step reconciliation preserving prior results and rejecting never-invoked/complete steps |
| `Sources/Macventory/AppModel.swift` | Presentation-bound verification, accurate history after verified completion, synthetic path isolation and embedded QA vendor fixture |
| `Sources/Macventory/ManagementView.swift` | Busy OK disabled, verification offered only for eligible result state, fresh manager artifacts shown |
| `Tests/MacventoryCoreTests/FinalUninstallAuditTests.swift` | New independent suite: mapping/presence redirection, retained fonts, combined/skipped results, exact launch, ACL grant, profile conflict, sibling association and executable replacement |
| `Tests/MacventoryCoreTests/UninstallExecutionTests.swift` | Admin deny/malformed/peer requirements, payload substitution, moved/offline libraries; existing positive helper test explicitly injects authorization boundary |
| `Tests/MacventoryCoreTests/InstallationHealthTests.swift` | Multi-version cask block; realistic embedded vendor fixtures with executable metadata |
| `Tests/MacventoryCoreTests/UninstallTests.swift` | Replace scheduler-dependent reentrancy timing with continuation gate |
| `Macventory.xcodeproj/project.pbxproj` | Regenerated to include the new test source; no hand-edited workflow or deployment change |
| `scripts/package-release.sh` | Publication preflight moved before output-changing build/package work |
| `SECURITY.md` | Document per-request authority, authenticated XPC and trusted-ancestor checks |
| `Docs/UNIFIED_UNINSTALL_AND_HEALTH.md` | Remove developer-specific absolute Markdown path while preserving original receipt investigation |
| `Docs/UNINSTALL_EXECUTION_LEVELS.md` | Mark as earlier-pass report and describe ignored evidence without broken repository links |
| `Docs/UNINSTALL_FINAL_AUDIT.md` | This independent findings, evidence, risk and Git review |

The review covered all 56 files changed by the existing feature commit, including the smaller domain/filter/sort/scanner/UI/test changes and both helper plists, Package.swift and generated project. Referenced unchanged native Trash, process, cache, leftover-history, packaging, artifact-validation, project scheme and CI/toolchain components were traced where relevant. The appendix records the complete feature-path review inventory so untracked implementation cannot be accidentally omitted.

## F. Remaining risks and release gates

1. **Privileged deployment:** a real matching-team Developer ID app/helper, Service Management registration/revocation, authorization denial/expiry/cancellation under real OS policy, message identity, helper crash/restart, concurrent requests, update/version compatibility and old-helper retirement must be exercised in a separately authorized disposable environment. No root service was activated here. Default ad-hoc builds correctly cannot use the privileged route.
2. **Actual provider effects:** no real Homebrew/MacPorts/Nix mutation, Finder Trash, Store removal, vendor tool launch or Steam completion was tested. Fake state changes establish orchestration/verification contracts, not third-party behavior. Setapp/Toolbox lack verified targeted integration; guidance is an explicit capability limit. A universal silent vendor CLI remains unsupported.
3. **External races and recipes:** official managers and native path APIs cannot atomically bind every validated object to later external execution. Immediate checks narrow the window; effects may complete after timeout/cancellation. Managers may execute their own trusted installed procedures. MacPorts bounded CLI postflight is not a complete residual-filesystem audit. Native/PKG/Store removal is explicitly bundle-only.
4. **Vendor scope:** matching signed embedded association is stronger than a sibling name/team guess, but it does not prove that a vendor app waits for user input or removes only one product. The user must review the disclosed vendor-defined scope; no automatic external-data cleanup is claimed. Individually reviewed vendor contracts are required for external/silent tools.
5. **Compatibility:** full Xcode project build, actual XCUITest, macOS 13 execution, Intel optional support, clean-machine Gatekeeper and notarization are pending. Do not infer them from the SwiftPM build or ad-hoc codesign check.
6. **Packaging/release:** local scripts deliberately sign ad hoc and have fixed versioned outputs. A future distribution must sign core/helper before the outer app with the correct identifiers, matching team and hardened runtime; notarize/staple and validate a clean install/upgrade and helper lifecycle. Version/build and helper update policy must be reviewed for that release. No published v1.0.0 artifact, installer layout or Tap was replaced.
7. **Accessibility and performance:** native labels/basic navigation, both appearances and window zoom were checked; full spoken VoiceOver/focus traversal is pending. Benchmarks cover cached rows and ordinary live inventory, not thousands of ports, all remote libraries or worst-case signed-bundle traversal. Full ownership scans are deliberately repeated at destructive boundaries; do not remove them merely for speed.
8. **Documentation freshness:** earlier reports preserve historical results and staged-state claims. This audit's actual HEAD, index and validation results supersede them. Official provider interfaces can change; the documented Nix version/mode boundary is deliberate.

## G. Git review

- Branch remains `feature/unified-uninstall-and-inventory-health`.
- HEAD remains `7422449068ed0dc82638598a8266d34be0e5c056`; review baseline is its parent `22334cd`.
- Audit-start staged, unstaged and untracked files: **none**. The previous 38 staged paths had already been committed before this audit started.
- Final staged files: **none**. The original committed feature is preserved; no stage/unstage/reset/rebase/clean operation was performed.
- Audit working changes are precisely the files listed in section E. There are **23 audit changed/new paths: 21 tracked modifications and two new files**. The two new untracked files are this report and `Tests/MacventoryCoreTests/FinalUninstallAuditTests.swift`; both must be included in a later approved audit-fix commit. Generated project changes are necessary for the new test file.
- No unrelated modifications were found in the initial tree or introduced intentionally. Ignored compiler outputs, unique QA bundle/ZIP, local logs/screenshots/benchmark export are evidence and are excluded from commit scope.
- No commit, push, merge, tag, release, Tap change, CI dispatch or external message was made. No real application/package/manager state/process/user data was removed, moved, modified, cleaned, repaired or Force Quit. Only disposable test fixtures and the uniquely identified audit QA app were changed; the QA app was quit normally.

## H. Recommendation

**COMMIT READY**, limited to recording this feature's audit fixes and regressions after explicit approval. There is no known unfixed critical/high issue established by this review. **NOT RELEASE READY** until the gates in section F are completed; the privileged route in particular is not certified by compilation and fake-authorizer tests.

The next step is to review the local combined audit diff, approve a commit including both new files, then separately approve a push and the exact isolated CI run described above. Do not rewrite or recreate the already-existing feature commit automatically.

Requested proposed commit message: `feat: complete unified source-aware uninstall execution`.

### Primary references checked for security decisions

- [Apple Authorization Concepts](https://developer.apple.com/library/archive/documentation/Security/Conceptual/authorization_concepts/02authconcepts/authconcepts.html): authorization must be checked in the helper for each privileged operation. No deprecated execute-with-privileges call was used.
- [Apple Authorization Services tasks](https://developer.apple.com/library/archive/documentation/Security/Conceptual/authorization_concepts/03authtasks/authtasks.html): external authorization forms and helper-side rights checks.
- Installed Apple SDK headers: `NSXPCConnection.h` message signing requirements (macOS 13); `NSWorkspace.h` running-app substitution default; `Authorization.h`/`AuthorizationTags.h` rights/external-form lifetime. Installed Darwin ACL manpages plus a disposable file probe established empty-ACL semantics; no installed file permissions were modified.
- Installed Homebrew `cask/artifact/moved.rb`, `move_back`: normal missing-target refusal was verified by reading source, never by attempting uninstall.

## Appendix: complete feature review inventory

- `Docs/ARCHITECTURE.md`
- `Docs/SOURCE_SUPPORT.md`
- `Docs/UNIFIED_UNINSTALL_AND_HEALTH.md`
- `Docs/UNINSTALL.md`
- `Docs/UNINSTALL_EXECUTION_LEVELS.md`
- `Macventory.xcodeproj/project.pbxproj`
- `Package.swift`
- `README.md`
- `Resources/Helpers/MacventoryPrivilegedHelper-Info.plist`
- `Resources/Helpers/org.vadimtanel.Macventory.macports-helper.plist`
- `SECURITY.md`
- `Sources/InventoryVerify/main.swift`
- `Sources/Macventory/AppModel.swift`
- `Sources/Macventory/DetailsView.swift`
- `Sources/Macventory/InventoryTable.swift`
- `Sources/Macventory/InventoryView.swift`
- `Sources/Macventory/ManagementView.swift`
- `Sources/Macventory/UninstallView.swift`
- `Sources/MacventoryCore/AppDataSafety.swift`
- `Sources/MacventoryCore/BundleRemovalAdapter.swift`
- `Sources/MacventoryCore/CaskArtifactMapping.swift`
- `Sources/MacventoryCore/Domain.swift`
- `Sources/MacventoryCore/HomebrewRemovalAdapter.swift`
- `Sources/MacventoryCore/HomebrewScanner.swift`
- `Sources/MacventoryCore/HomebrewTrust.swift`
- `Sources/MacventoryCore/InstallationHealth.swift`
- `Sources/MacventoryCore/InteractiveRemoval.swift`
- `Sources/MacventoryCore/InventoryCategorySelection.swift`
- `Sources/MacventoryCore/InventoryService.swift`
- `Sources/MacventoryCore/InventorySort.swift`
- `Sources/MacventoryCore/MacPortsAuthorization.swift`
- `Sources/MacventoryCore/ManagedRemoval.swift`
- `Sources/MacventoryCore/ManagementWorkflow.swift`
- `Sources/MacventoryCore/ManifestScanners.swift`
- `Sources/MacventoryCore/NativeScanner.swift`
- `Sources/MacventoryCore/OfficialRemovalDocumentation.swift`
- `Sources/MacventoryCore/PackageScanners.swift`
- `Sources/MacventoryCore/ProcessRunner.swift`
- `Sources/MacventoryCore/SourceRemovalGuide.swift`
- `Sources/MacventoryCore/StandaloneRemoval.swift`
- `Sources/MacventoryCore/Uninstall.swift`
- `Sources/MacventoryCore/UninstallExecutionService.swift`
- `Sources/MacventoryCore/UninstallLevels.swift`
- `Sources/MacventoryCore/UninstallPreparation.swift`
- `Sources/MacventoryCore/VendorRemovalAdapter.swift`
- `Sources/MacventoryCore/VendorUninstaller.swift`
- `Sources/MacventoryPrivilegedHelper/main.swift`
- `Tests/MacventoryCoreTests/InstallationHealthTests.swift`
- `Tests/MacventoryCoreTests/InventoryTests.swift`
- `Tests/MacventoryCoreTests/ManagementWorkflowTests.swift`
- `Tests/MacventoryCoreTests/ToolboxModernTests.swift`
- `Tests/MacventoryCoreTests/UninstallExecutionTests.swift`
- `Tests/MacventoryCoreTests/UninstallTests.swift`
- `UITests/MacventoryUITests.swift`
- `scripts/build-app.sh`
- `scripts/generate-project.py`
