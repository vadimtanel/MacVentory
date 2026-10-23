# Native GUI QA — Macventory 1.0.0

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
