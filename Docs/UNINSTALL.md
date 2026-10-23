# Single-application uninstall

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
