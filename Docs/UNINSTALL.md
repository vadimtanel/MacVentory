# Single-application uninstall

Current feature behavior, execution-level matrix and validation are documented in [Uninstall execution levels](UNINSTALL_EXECUTION_LEVELS.md). That report supersedes the earlier pass and historical uninstall limits below. Historical build notes remain for context.

Build107 clarifies whole-folder targeting: the selected directory URL, including its contents, is submitted as one native Trash target. It does not submit only child files or remove unselected parent directories. Permission errors now distinguish reading the target, checking parent writability and Finder rejection with underlying domain/code. Review access in macOS Privacy & Security yourself; no automatic grants, elevation or bypass are implemented. A readable directory can still be protected against modification.

## Build106 cleanup and optional personal locations

Cleanup now distinguishes No Longer Exists/Already Removed from Permission Denied, Changed Since Scan, Cleanup Failed and Outcome Unknown. Already absent items are reconciled immediately and never credited as deletions. Independent selected items can proceed only after their own preflight; duplicates/nesting block submission, and unknown native outcomes stop remaining requests without automatic retry. A partial scan can remove confirmed stale observations while retaining inaccessible/inconclusive entries and their errors.

The Scanning setting “Discover related folders in Documents, Downloads and Desktop” defaults off. Enabling it permits bounded direct-child suggestions based on known identities, with a manual-review warning, individual selection, exact paths and explicit confirmation. Suggestions never enter Select All Verified Data. Shared/ambiguous/protected/linked targets remain blocked. This opt-in behavior supersedes earlier text excluding all personal-location discovery. Discovery does not authorize deletion, bypass macOS privacy restrictions or request elevation.

## Identity correction

The local identity index retains friendly names and embedded-bundle parent relationships after applications disappear. Snapshot migration preserves existing bundle name evidence; removal records and bounded exact-ID local manifests provide fallback names. Application groups join identifiers only using recorded parent relationships, superseding any same-name grouping description below. Names and parent associations never authorize cleanup or upgrade Possible Related Files. Last observed is not uninstall evidence. Unresolved names keep their identifiers; absent helper evidence keeps components separate. Launch Services is used for installed/reinstalled exclusion; a missing registration is never treated as proof of exclusive ownership.

## Current workflow — build 104 (supersedes build 103 UI)

One item-based sheet serves row double-click/Return, the details Uninstall button and right-click Uninstall…. Its title is the neutral **Application Name**, followed by version/source information and operation-specific status. The context menu contains Copy Identifier, Reveal in Finder, Copy Path, a conditional Force Quit, and Uninstall…; redundant management/data entries are removed. Normal Quit remains the application’s native command; the management sheet offers the three independently eligible Force Quit/Clear App Data/Uninstall checkboxes.

The sheet owns immutable review identity and a single-use execution request. Selection changes reset acknowledgment. Execution validates all selected targets first, stops/verifies the reviewed process, moves selected data, then uninstalls; failure or partial cleanup skips subsequent steps. Completed, partially completed, failed and cancelled states show per-step results and one **OK** button. Dismissing clears the actual presentation binding; inventory refresh is deferred until dismissal. No terminal result retains executable controls.

Data scans/size summaries run away from the main actor. Native Finder callbacks have a 30-second watchdog and single-resume completion gate. Timeout means unknown outcome, not cancelled deletion: an already submitted request may finish later. Process identity also binds launch date against PID reuse/restart; related bundled helpers block later data cleanup if still running. Uninstall’s existing source ownership, freshness, fingerprint, permissions and final stopped-process checks remain intact.

Leftover Data performs general bounded discovery from normal Library sources and local exact-ID manifests, with no hardcoded application names/IDs. Installed/reinstalled apps are cross-checked with current inventory and Launch Services. Only groups with files are actionable. Application grouping combines only independently recorded or metadata-backed product names; Identifier grouping remains available for technical review. Unknown retrospective identities and records older than 30 days cannot authorize Select All Verified; name matches remain possible, group containers protected. Partial scans preserve prior observations and identify the affected Library location, permission state and retry action. Candidates outside the affected location may be selected only when their own preflight checks still establish safe ownership; failed/cancelled scans require a retry. Manually nominated home subfolders remain possible-only. Arbitrary undocumented vendor layouts and every file ever created cannot be reliably discovered.

## Application management — build 103

Macventory now presents independent **Quit**, **Force Quit**, **Clear App Data**, and **Uninstall** choices through **Manage Application…**. A single explicit review checkbox gates the selected operations; their execution order is process action, confirmed process exit, selected data to Trash, then uninstall. Failed critical steps stop later steps, and the result lists partial successes rather than claiming a rollback or complete cleanup.

Force Quit is a native `NSRunningApplication` request, not a `killall`/`pkill` name match. The selected canonical bundle URL and bundle identifier must both match the running process at review and immediately before execution. Normal Quit remains distinct; Force Quit warns about unsaved changes. System components, Macventory itself, and uncertain targets are unavailable.

Clear App Data checks exact application-specific locations under the current user’s Library. Exact bundle-ID containers, preferences, caches, logs, WebKit and saved state can be verified. Exact display-name support/cache folders are possible-only and require individual selection; group containers remain protected because they may be shared. All selected targets are revalidated for identity, root containment, symlink substitution, duplicate/nested paths and accessibility before native Finder Trash submission. It does not use `rm`, permanent deletion, broad home scans, or package-manager cleanup.

The **Leftover Data** sidebar view works when an app no longer exists. Macventory preserves a minimal recently-removed identity record only after a confirmed Macventory removal and also offers bounded retrospective discovery by exact identifier for externally removed software. The Kimi identifier is an investigation hint, not proof. Documents/Downloads/Desktop/external paths are user-chosen review items and are never included in Select All Verified Data.

Discovery remains read-only. Uninstall is a separate, explicitly requested operation, never automatic or bulk. Double-click a row, press Return, or choose **Uninstall…** to see its exact name, version, source, path, operation and any manager arguments. An executable plan requires the review checkbox and explicit operation-specific confirmation. Canceling the preview never executes it.

| Source | Current behavior |
|---|---|
| Homebrew Cask | A fresh, verified receipt must map exactly one app artifact to this bundle and contain no executable removal hooks or additional removal artifact types. Preview the exact installed brew executable and `uninstall --cask -- token`. No force, zap, autoremove or cleanup. Other casks receive external guidance. |
| Direct / Unmanaged | Separate standalone eligibility review; qualifying user-owned bundles directly in standard Applications folders offer **Move to Trash**. Source remains inferred. Native NSWorkspace recycle moves only the bundle. No permanent deletion or external-data cleanup. |
| Mac App Store | External guidance; receipt presence alone cannot authorize Trash. |
| PKG | Vendor uninstaller guidance. A receipt is not an inverse installation script. |
| Steam / Setapp / Toolbox | Source application uninstall guidance. Inferred manager association cannot authorize removal. |
| Formulae / MacPorts / Nix | Manager handoff; review dependents outside Macventory. No automatic package or dependency removal. |
| Unknown / conflicting / system / running / stale | Blocked. Refresh or quit the target yourself where appropriate. |

The planner, fresh validator, single-use confirmation session and executor are separate. Immediately before execution, revalidate path, bundle identity, receipt/config fingerprint, ownership, running status and confirmation age. Evidence reads are bounded. Execution uses argument arrays, no shell, no elevation, no automatic retry, no force and no data sweep. Failures explain that a manager operation may be partially applied. Cancellation of an already-started operation is best effort, not rollback.

Production adapters are implemented but **actual destructive execution is unverified**. Homebrew's own behavior and concurrent external changes remain outside Macventory's full control. This is a release gate; do not infer tested removal safety from passing planning tests.

## Development and QA

**No real application/package was removed or modified during this pass.** Tests inject recording/simulated executors and synthetic temporary bundles; the live executor is never called. `--ui-testing` isolates settings and uses fake records; `--safe-qa` reads real inventory but forces simulated execution and displays a visible protection banner. QA confirmation was performed only on a synthetic Example App. The synthetic target remained present.

Automated tests cover plan-bound confirmation, cancellation, single-use behavior, changed targets, mocked permission/execution failures, protected/uncertain sources, source handoffs and safe cask arguments/hook rejection. Actual GUI checks cover disabled confirmation, checkbox gating, preview cancellation and simulated success. No uninstall command was executed, including against disposable fixtures. A separately authorized controlled environment is required for destructive verification.

All prior uninstall safety tests are retained. Demo mode uses fictional records with no installation paths, offers blocked previews and independently blocks plans carrying the synthetic marker. Demo never instantiates real providers or the live removal adapter. Information explains cache scope; its cache action is disabled in isolated modes. No real cache was cleared.

## 1.0.0 confirmation update

No typed name is required. The checkbox starts unchecked and belongs to the immutable plan UUID. Cancel/Escape close immediately before execution. Replacement plans reset acknowledgment; stale/wrong IDs, missing acknowledgment and duplicate/concurrent confirmations are rejected. The session consumes confirmation before awaiting fresh validation; failures require a newly prepared plan. The final validator and production adapter still verify exact source/target/operation and do not trust the checkbox alone.

The preview wraps full names/paths, scrolls long identity/operation text and puts exact command arguments inside expandable Operation details. Progress/results are visible; simulation is labeled prominently. Single-click/details and right-click Copy Identifier/Reveal/Copy Path/Uninstall remain; native double-click/Return only open review. Packages/system components remain blocked or handed off, never coerced into bundle removal.

## Successful completion

A successful operation becomes a final read-only state with one OK button. It shows “Operation completed.” followed on a new line by “Refresh the inventory to verify the remaining installation state.” Simulation instead reports that nothing was removed or modified. Confirmation, cancellation and removal controls are hidden once successful. Errors keep their failure/cancellation handling; they are not presented as success.


## Standalone Move to Trash — build 102

The preview performs a cancellable, fresh read-only audit with the existing eight manager/installer scanners and no cached observations or size traversal. Every source must finish successfully or be absent. Any exact, containing or contained payload/related-path claim blocks Trash, including inferred provider claims. Default Homebrew prefixes are always checked alongside configured prefixes; changed MacPorts/Nix executables cannot hide an installed default manager. Unsupported/failed/canceled/missing source reports fail closed. PKG receipt/payload limits now report incompleteness rather than silently authorize absence.

Eligibility additionally requires an existing non-linked top-level `.app` in `/Applications` or the current user's Applications folder, a local writable volume, current-user ownership, writable parent, no immutable/append-only flags, matching non-Apple/non-Macventory bundle identity, APPL metadata and an executable regular file inside the bundle. All ancestor directories and the Info.plist/executable paths must be free of symlinks. Linked/alias discovery remains recorded after inventory canonicalization. Known store/provider markers, privileged helper declarations, login items, launch agents/daemons, system/driver/kernel extensions and helper-tool directories block the operation. Ordinary bundled share extensions remain inside the bundle and do not imply external ownership.

A fingerprint binds device/inode identity, Info.plist content, executable identity/size/modification time, bundle modification time and parent identity. Confirmation remains UUID-bound, initially unchecked and single use. The validator repeats the ownership audit and checks freshness/running state; the live adapter repeats it independently, then checks filesystem identity and running status on the main queue immediately before calling [NSWorkspace.recycle](https://developer.apple.com/documentation/appkit/nsworkspace/recycle(_:completionhandler:)). It submits one URL and requires a corresponding returned Trash URL. Permission failures and missing result mappings are errors; there is no force, elevation, automatic retry, permanent-delete fallback or external-data sweep. A successful result keeps the exact two-line message and OK-only state.

No path-based Finder API can atomically bind an already-inspected inode to a later rename. Immediate checks narrow that external-race window but do not eliminate it. Arbitrary vendor components and unrecognized manager layouts cannot be proven absent; this is scoped bundle removal, not a complete uninstall or proof of download origin. Nonstandard roots, other users' apps and root-owned bundles intentionally remain unsupported. An operation submitted to Finder cannot guarantee cancellation/rollback; recover the bundle through Finder's Trash if appropriate.

Synthetic tests exercise inferred-origin eligibility, blocked paths and service/provider markers, symlink/alias discovery, manager claims/incomplete audits, changed ownership/executable identity, confirmation, cancellation and mocked permission/execution failures. Simulated eligibility cannot reach the native Trash adapter. No test calls a real removal adapter or moves even a disposable fixture to Trash. Live destructive behavior remains unverified and requires separate authorization in a controlled environment.
