# Installing Macventory 1.0.0

## DMG

Download Macventory-1.0.0-arm64.dmg from the official repository's Releases page when published. Open it, drag the official Macventory icon onto Applications, eject the disk and launch Macventory from Applications or Spotlight. The image is compressed/read-only and contains the self-contained app plus an Applications symlink. No privileged installer, package-manager operation or post-install script is needed. The app inherits the destination user's ordinary filesystem permissions.

## ZIP

Extract Macventory-1.0.0-arm64.zip and copy Macventory.app into Applications. SwiftPM, Xcode and the repository are development tools, not end-user runtime requirements. arm64 is primary; M1–M5 intended, only M4 Pro/macOS 27.0.1 actually tested. macOS 13 deployment is configured, but minimum-OS execution remains unverified.

## Integrity and first launch

Compare the downloaded file's SHA-256 against the accompanying official release checksum file. The checksum detects corruption/substitution relative to that file, not an independent publisher identity. An optional Terminal check is `shasum -a 256 Macventory-1.0.0-arm64.dmg`; installing itself requires no Terminal commands.

The local signature is ad-hoc. It seals the bundle but is not a Developer ID certificate. Developer ID signing and Apple notarization are separate paid-program distribution services; neither is required by this project's build/package pipeline. Gatekeeper independently evaluates downloaded software and may block it. No Apple verification/notarization is claimed.

Attempt to open the app and read the warning. If you independently trust the official source and checksum, use System Settings → Privacy & Security → Open Anyway where macOS provides it, then respond to the normal system prompt. This is the user's explicit per-app exception, never an automatic operation. Do not clear quarantine programmatically or globally disable Gatekeeper/SIP. Do not bypass malware/damaged-app warnings. Managed policy or OS differences can prevent this option; universal launch success is not guaranteed. [Apple guidance](https://support.apple.com/102445).

## Verification limits

Development QA copies only into project-owned temporary destinations; it never overwrites the owner's installed Macventory or drags onto the real Applications shortcut. Read-only mount, alias target, native Finder layout, permissions, bundle/resource/signature checks and temporary-copy launch are documented in VERIFICATION.md. Clean downloaded/quarantined-machine first launch remains pending. A public source repository can be reviewed/published independently of binary distribution checks, subject to owner approval.
