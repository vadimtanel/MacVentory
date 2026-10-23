# Release preparation

Official repository: https://github.com/vadimtanel/MacVentory

The existing LICENSE commit is preserved. Application source/metadata/initial commit/push and releases require owner approval; no publication action is performed by packaging scripts. See GIT_INTEGRATION.md for the current safe integration plan and PUBLICATION_REVIEW.md for the proposed first application commit.

## Local artifacts

```sh
bash scripts/package-release.sh
```

Builds an optimized native app, ad-hoc signs it, stages a two-item DMG with Applications link and a native Finder installation background (license/NOTICE inside the app), and creates architecture-labeled ZIP, DMG, source archive and SHA-256 files under artifacts/. Primary distribution is arm64. Intel is optional and must not be labeled verified or universal without evidence.

Verify checksums, app/ZIP signatures and DMG integrity; inspect the mounted image read-only and launch the extracted ZIP using `--demo` for safe review. Do not invoke real removal or cache clearing. After final documentation changes, refresh source archive/checksums. Exclude build/private inventory reports and old screenshots from source packages.

## Verification and approval before publication

- Current unit/fixture/safety/live tests and native arm64 app build pass.
- Actual main/settings/Information/About GUI and safe public screenshots reviewed.
- Full Xcode build/XCUITest and hosted CI actually run; preparation is not a passing execution.
- Full VoiceOver navigation documented if claimed; minimum-OS and clean-machine Gatekeeper behavior assessed.
- Source matrix and production uninstall risk reviewed. Actual destructive behavior needs separately authorized controlled testing, never the owner's installed software.
- License/NOTICE, public file manifest, privacy audit, resources, version and checksums reviewed.
- Owner explicitly approves commits, push and any release publication separately.

Intel execution is not a release requirement. M1–M5 are intended Apple Silicon targets; only M4 runtime has been checked here. Current deployment target is macOS 13; actual host is macOS 27.0.1.

## Xcode when available

```sh
xcodebuild -project Macventory.xcodeproj -scheme Macventory \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData \
  -resultBundlePath build/Macventory.xcresult \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual test
```

Full Xcode is unavailable on the current machine; no Apple authentication/install retry is planned. CI has a primary arm64 job and an optional Intel check. Workflow files are prepared, not executed here. Runner labels follow [GitHub's runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

Free/ad-hoc distribution is the explicit project policy. Paid Apple Developer membership, Developer ID and notarization are not required and are not packaging blockers. Ad-hoc signatures do not provide notarized distribution trust; downloaded builds may be blocked. Explain the supported, user-initiated Privacy & Security → Open Anyway procedure where offered; never automate that choice, clear quarantine or disable protections. See INSTALLATION.md. Public source preparation is independent of binary clean-machine verification.

## Proposed metadata (not applied)

Preserve the existing repository description. Suggested topics for owner review: macos, swift, swiftui, homebrew, software-inventory, app-manager, uninstaller, apple-silicon, open-source. Do not change repository settings without approval.
