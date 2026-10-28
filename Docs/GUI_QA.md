# Native GUI QA — Macventory 1.0.0

**Historical report.** v1.1.0 was released on 27 October 2026 with passing native/GUI CI. See [current verification](VERIFICATION.md) for completed checks and manual VM testing. Failed/pending checks, branch state and proposed next steps below apply only to the dated development pass.

## Build107 native synthetic checks

Command-click selected Direct/Unmanaged plus Homebrew Formulae, showed both highlights and three combined fixture rows, then search narrowed to one matching tool. Leftover Data replaced the inventory-category selection. A mock access denial reported its exact check/path and retained recovery help after OK. System Settings launch was disabled in QA. Personal discovery status was visibly off; Scanning Settings shortcut was corrected and rechecked opening Scanning directly. Enabling it showed synthetic Documents/Downloads/Desktop folders requiring individual selection. Confirmation explicitly says folders move whole with their contents. Only isolated QA was closed/rebuilt; real app/process/data/settings remained untouched.

## Build106 stale/optional-personal actual checks

Separate Cleanup QA app with persistent isolation and flags for mock missing/partial/denied outcomes. Native GUI verified default-off personal discovery, Already Removed result and empty-group reconciliation, mixed independent outcomes (absent, simulated move, permission denied), retained denied/protected data with updated counts and sizes, protected checkbox disabled, and one OK restoring interaction. Settings opt-in then added synthetic Documents/Downloads folders to Orchard Notes with Possible Related Files — Manual Review Required. An injected Desktop denial appeared in View Scan Issues. Personal candidates stayed unchecked and excluded from verified bulk selection; individual selection opened exact-path review with a disabled confirmation until acknowledged. Cancel returned without execution. Turning discovery off removed personal suggestions and warning. No real or synthetic file was moved by GUI actions. Final minor result-summary deduplication was compiled after the native pass.

## Identity correction — build105 source

Actual native QA used the separate org.vadimtanel.Macventory.identity-qa app, launched without arguments. Its persistent QA marker forced synthetic data and simulated operations. Verified retained Orchard Notes name, Retired Studio/Share parent grouping, unrelated similar identifiers separate, technical Identifier mode, name/identifier/path search and retained names after refresh. Verified bulk selection checks only verified parent candidates, possible helper remains unchecked; individual possible-file confirmation, simulated cleanup result/OK/refresh, and Force-Quit-only neutral title/result/OK restoration all passed. Production user data and processes were untouched. Final minor search/fallback copy polish is compiler/test-verified; full automated XCUITest remains unavailable without full Xcode.

## Build 104 actual correction checks

The current pass used separately identified QA copies with `--ui-testing`, mock running identities and simulated execution. Verified both context menus (Force Quit only on the running row; Copy Identifier/Reveal/Copy Path/Uninstall preserved; redundant entries absent), double-click title, independently eligible operations, all-three ordered execution, exact candidate review, verified-only selection, successful OK-only completion, failure OK-only result, Cancel, reopening and main-window interaction after dismissal. Leftover Data showed two actual fixture groups, excluded Empty Removed App, and after simulated cleanup removed Retired Studio while preserving the no-history group. No fixture was moved or deleted by GUI operations.

The old packaged binary available locally did not contain the advanced management UI, so it could not replay the owner's original frozen instance. The invalid dual-state sheet transition and missing terminal branch were identified in build-103 source. The corrected end-to-end native flows were then directly exercised. A transient QA-only fixture-path issue at macOS's /tmp alias was caught by strict validation; fixtures were returned to ignored build roots rather than weakening the live symlink checks.

Native app icons from the fixture bundle and generic CLI fallback were visually inspected. New cursor regions preserve native text/edit/resize behavior and disabled-control checks; exhaustive hover/VoiceOver verification is not claimed. Full Xcode/XCUITest is unavailable. Production termination, Trash and uninstall behavior remains intentionally untested.

Final injected partial cleanup displayed **Partially completed.**, preserved Force Quit success, marked data cleanup partial, skipped Uninstall and offered only OK; OK restored the inventory. Light/Dark leftovers layouts were directly captured after committing appearance in isolated settings. The new public `macventory-leftover-data.png` contains no personal paths or real inventory. Minimum-size resizing could not be driven reliably through the exposed corner-drag action and remains unverified. Settings footer presentation from Leftover Data was corrected at the split-view root and has a dedicated XCUITest regression.

The ZIP-extracted release app was verified byte-for-byte before a disposable copy received a unique QA display name/identifier and re-signature. Its explicit `--ui-testing` launch showed synthetic fixtures. Settings footer open/Cancel, search, confidence filtering, cleanup review, simulated completion, single OK, refresh and empty-filter rendering all passed in that packaged binary. A stale handle elsewhere reopened a QA copy in normal mode during read-only observation; no management/cache-clear action ran, but shared cache modification from its normal scan cannot be ruled out. The installed Applications copy was left running.

Actual supported computer-use interaction, not just launch/compilation. Uninstall success used --ui-testing with an injected simulated executor; public captures used isolated --demo. No real installed target was removed or modified. An older project-built normal instance was closed before interacting, ensuring QA tools bound to the protected instance.

## Current observations

- Single click selected/details without a preview; double-click/Return opened review. Header double-click sorted without a dialog. Right-click retained item-specific Copy Identifier, Reveal, Copy Path and Uninstall actions.
- Synthetic eligible preview displayed icon/full identity/source/path/operation and retained-data explanation. Checkbox initially unchecked; Uninstall disabled. Check enabled it; Cancel closed; reopening reset acknowledgment. Simulation reported nothing removed/modified.
- Package and protected synthetic macOS component showed blocked reasons/identity and disabled Uninstall. No name text field remains.
- Final DMG-copied app tested with two inventory windows: preview only in requesting window; double-click from the other window did not duplicate it. Original plan remained unchecked until explicitly confirmed. Simulation completed.
- Settings staged Dark while Light stayed visible, and staged Light/System while Dark stayed visible. Escape, Cancel after several edits and native Settings-window close discarded drafts. Done applied Dark; reopening retained it. Runtime counters separated appearance-only zero-rescan commit from system-discovery one-refresh commit.
- About1.0.0 links/credit, unframed logo and all ten synthetic categories inspected. Real configuration/cache SHA-256 remained unchanged.
- Final DMG inspected read-only after staging image detach: two icons, resolved background/arrow/instructions, working /Applications link. App copied only into project test folder and launched with protected fixtures; actual installation into /Applications not attempted. ZIP-extracted demo app launched/rendered as well.

## Public evidence

Five actual window captures under Screenshots/: macventory-inventory-light.png, macventory-inventory-dark.png, macventory-settings.png, macventory-about.png, macventory-installer.png. All refreshed from final1.0.0 packages; inventory is fictional. No public success dialog uses private temporary bundle paths. Previous private/obsolete captures remain under ignored build/.

## Limits

Earlier real GUI evidence covers six-header directions, combined filters, selection, missing/empty/error states, refresh/cancel, column hide/reset and resizing. Current unit tests preserve these paths; no claim every old interaction was repeated. Full VoiceOver was not enabled/navigated; native AX labels/roles are not substituted for it. Full Xcode/XCUITest unavailable; native column dragging and complete keyboard/hover audit remain unverified.

## Build101 focused checks

Simulated completion removes the checkbox, Cancel, Uninstall and expandable operation controls. Only read-only identity/result and OK remain; OK dismisses. Exact two-line production copy is covered by unit test, never a live removal. Final toolbar/About artwork and read-only DMG Finder icon visually inspected. ZIP runtime confirms official icon loading and post-launch assignment. Direct Dock capture timed out; visible Dock appearance is unverified.
