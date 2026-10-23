# Single-application uninstall

Discovery remains read-only. Uninstall is a separate, explicitly requested operation, never automatic or bulk. Double-click a row, press Return, or choose **Uninstall…** to see its exact name, version, source, path, operation and any manager arguments. An executable plan requires the review checkbox and explicit Uninstall confirmation. Canceling the preview never executes it.

| Source | Current behavior |
|---|---|
| Homebrew Cask | A fresh, verified receipt must map exactly one app artifact to this bundle and contain no executable removal hooks or additional removal artifact types. Preview the exact installed brew executable and `uninstall --cask -- token`. No force, zap, autoremove or cleanup. Other casks receive external guidance. |
| Direct / Unmanaged, Mac App Store | Bundle-only Trash adapter exists for explicitly verified standalone eligibility. Discovery does **not** infer that eligibility from bundle or receipt presence, so ordinary scanned apps currently receive vendor guidance. Trash is described as bundle-only removal, never a complete uninstall. |
| PKG | Vendor uninstaller guidance. A receipt is not an inverse installation script. |
| Steam / Setapp / Toolbox | Source application uninstall guidance. Inferred manager association cannot authorize removal. |
| Formulae / MacPorts / Nix | Manager handoff; review dependents outside Macventory. No automatic package or dependency removal. |
| Unknown / conflicting / system / running / stale | Blocked. Refresh or quit the target yourself where appropriate. |

The planner, fresh validator, single-use confirmation session and executor are separate. Immediately before execution, revalidate path, bundle identity, receipt/config fingerprint, ownership, running status and confirmation age. Evidence reads are bounded. Execution uses argument arrays, no shell, no elevation, no automatic retry, no force and no data sweep. Failures explain that a manager operation may be partially applied. Cancellation of an already-started operation is best effort, not rollback.

Production adapters are implemented but **actual destructive execution is unverified**. Homebrew's own behavior and concurrent external changes remain outside Macventory's full control. This is a release gate; do not infer tested removal safety from passing planning tests.

## Development and QA

**No real application/package was removed or modified during this pass.** Tests inject recording/simulated executors and synthetic temporary bundles; the live executor is never called. `--ui-testing` isolates settings and uses fake records; `--safe-qa` reads real inventory but forces simulated execution and displays a visible protection banner. QA confirmation was performed only on a synthetic Example App. The synthetic target remained present.

Eleven automated tests cover plan-bound confirmation, cancellation, single-use behavior, changed targets, mocked permission/execution failures, protected/uncertain sources, source handoffs and safe cask arguments/hook rejection. Actual GUI checks cover disabled confirmation, checkbox gating, preview cancellation and simulated success. No uninstall command was executed, including against disposable fixtures. A separately authorized controlled environment is required for destructive verification.

The current 81-test suite retains all eleven uninstall safety tests. Demo mode uses fictional records with no installation paths, offers blocked previews and independently blocks plans carrying the synthetic marker. Demo never instantiates real providers or the live removal adapter. Information explains cache scope; its cache action is disabled in isolated modes. No real cache was cleared.

## 1.0.0 confirmation update

No typed name is required. The checkbox starts unchecked and belongs to the immutable plan UUID. Cancel/Escape close immediately before execution. Replacement plans reset acknowledgment; stale/wrong IDs, missing acknowledgment and duplicate/concurrent confirmations are rejected. The session consumes confirmation before awaiting fresh validation; failures require a newly prepared plan. The final validator and production adapter still verify exact source/target/operation and do not trust the checkbox alone.

The preview wraps full names/paths, scrolls long identity/operation text and puts exact command arguments inside expandable Operation details. Progress/results are visible; simulation is labeled prominently. Single-click/details and right-click Copy Identifier/Reveal/Copy Path/Uninstall remain; native double-click/Return only open review. Packages/system components remain blocked or handed off, never coerced into bundle removal.

## Successful completion

A successful operation becomes a final read-only state with one OK button. It shows “Operation completed.” followed on a new line by “Refresh the inventory to verify the remaining installation state.” Simulation instead reports that nothing was removed or modified. Confirmation, cancellation and removal controls are hidden once successful. Errors keep their failure/cancellation handling; they are not presented as success.
