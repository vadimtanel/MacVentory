# Preparing and publishing Macventory v1.1.0

Official repository: [vadimtanel/MacVentory](https://github.com/vadimtanel/MacVentory). Target branch: `main`. Candidate metadata is already **1.1.0 / build 108** in `Resources/Info.plist`; do not increment it again for documentation preparation.

v1.1.0 is upcoming. This preparation authorizes one reviewed documentation-only commit. Pushing requires the owner's separate approval. The owner will create the tag and publish the GitHub Release after final CI verification. Packaging scripts publish nothing. This process applies only to the application repository; the separate Homebrew Tap is not edited here.

## 1. Finalize documentation and source

Review README, changelog, installation, source support, uninstall/security and verification against the implementation. Preserve historical reports and published v1.0.0 references. Label upcoming links and unverified capabilities. Run:

```sh
python3 scripts/review-publication.py
git diff --check
```

Require **zero publication findings**. Review the generated manifest under ignored `build/` and the exact diff. Validate relative links/assets and check for private paths or unintended files. Preserve LICENSE, NOTICE, branding and screenshots. Verify branch, upstream, clean initial state and advertised remote main before committing; stop if main unexpectedly advanced or unrelated changes appeared. Stage only reviewed documentation paths. Do not reset, rebase, discard work or force-push.

## 2. Verify version, build and compatibility metadata

```sh
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist
/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Resources/Info.plist
```

Expected values: `1.1.0`, `108`, `13.0`. Package.swift and Xcode app/helper targets configure macOS 13; test-host requirements are separate. Inspect built app metadata against the source plist, not an older local package. arm64 is the release target. Intel/universal and minimum-OS runtime require independent evidence before being called verified.

## 3. Run complete CI on the final commit

After the owner approves pushing, record the exact commit SHA. A push triggers [Build and test Macventory](../.github/workflows/ci.yml); reuse that run instead of dispatching a duplicate. A manual diagnostic run with default `selection_scenario=isolated` is **not** full verification. A final manual run must explicitly select `full` on the intended ref and confirm the resulting `head_sha`.

Require successful native **and** UI jobs for that SHA:

- SwiftPM build and synthetic fixture tests; Xcode app build, all test-target compilation and isolated hosted Xcode unit tests.
- arm64 app/ZIP/DMG/source packaging and artifact validation.
- All **16 original primary GUI cases plus the selection regression** (17 total in the proposed stabilization patch), with no missing, skipped or failed cases; sequence verification, xcresult export, header comparison and independent pointer diagnostic steps. Inspect `gui-sequence.json`, actual Xcode terminal/exit results and retained logs/xcresults.

The workflow pins `macos-26` arm64 and Xcode 26.5, verifies the actual toolchain and disables opt-in live tests. The proposed stabilization patch removes primary GUI `continue-on-error`; subsequent evidence/diagnostic collection uses `always()` and cannot override a primary failure. Native-only success, an isolated diagnostic or the [package-only workflow](../.github/workflows/package.yml) is insufficient. See [CI details](CI.md).

At this stabilization checkpoint, the documentation commit is preserved on `release/v1.1.0-stabilization`, local `main` has been restored to the verified remote baseline, and further commits/pushes/PRs/dispatches require separate approval. Proposed local changes are not remotely validated. The next controlled sequence is one approved `isolated` run (original execution-level case plus selection-only regression), then one approved `full` run only after focused success. Recheck the exact candidate SHA at both stages; do not dispatch repeated full runs without a demonstrated change or reason.

Any later source **or documentation** commit changes the candidate SHA and source archive; repeat final CI for that commit. Synthetic CI does not establish real destructive uninstall safety, signed-helper deployment, minimum-OS runtime, VoiceOver or clean-machine Gatekeeper behavior. Resolve applicable release gates and disclose remaining limitations before claiming release readiness. The [disposable-environment plan](UNINSTALL_FOCUSED_VALIDATION.md) records real-effect scenarios requiring separate authorization.

## 4. Verify final packaging, checksums and assets

The unchanged scripts used by CI are:

```sh
bash scripts/package-release.sh
bash scripts/validate-artifacts.sh
```

They build/sign ad hoc and create/validate local versioned outputs. Running them can replace existing files under `build/` and `artifacts/`; documentation-only preparation does not run them or create release assets. Final-commit CI artifacts provide the packaging evidence.

Expected outputs:

- `Macventory-1.1.0-arm64.dmg`
- `Macventory-1.1.0-arm64.zip`
- `Macventory-1.1.0-arm64.sha256`
- `Macventory-1.1.0-source.tar.gz`

The validator checks arm64 app/helper architecture, strict signatures, version/build agreement, private compiler-path absence, DMG integrity, every checksum entry, ZIP bytes and source membership/hashes against the publication manifest. Retain logs and artifact hashes tied to the exact commit. Source packaging uses the reviewed publication set, not a recursive directory sweep. Regenerate source/checksums after any input change; never mix artifacts/manifests from different commits.

Review DMG Finder layout and ZIP extraction in disposable project-owned locations if needed; do not overwrite the owner's app for QA. No live removal, Force Quit, data cleanup or helper activation is part of documentation preparation. Default ad-hoc signing and removal scope remain limited as described in [installation](INSTALLATION.md) and [uninstall](UNINSTALL.md).

## 5. Owner creates the tag from the exact validated commit

After all applicable validation and review, confirm local/remote main identify the intended candidate. The owner creates **`v1.1.0` at that exact SHA** and pushes the tag. Do not tag a moving branch tip or use an older validation result. Do not create, replace or move a tag during documentation preparation; stop if an existing v1.1.0 tag points elsewhere.

## 6. Owner publishes the GitHub Release

Publish from the validated tag with the reviewed changelog, known limitations and four verified assets. Check public filenames/hashes against the retained outputs. GitHub-generated source archives are distinct from the manifest-reviewed `Macventory-1.1.0-source.tar.gz`. Mark the version published in public documentation only once the release exists. Documentation preparation creates no tag, release upload or repository-setting change.

Free/ad-hoc distribution remains project policy. Developer ID/notarization are not required for ordinary inventory or local packaging, and are not claimed. Ad-hoc signing cannot enable privileged MacPorts removal, which needs trusted matching app/helper signing and separately validated OS authorization/deployment. Do not weaken Gatekeeper, clear quarantine or activate a helper to make release checks pass.

## 7. Allow separate Homebrew Tap synchronization

Once the stable release is public, separate [Macventory Tap](https://github.com/vadimtanel/homebrew-macventory) automation detects and validates it before offering an update. Confirm availability through its own process; do not edit its Cask or assume immediate synchronization here. Installation/upgrade commands use the version the Tap currently provides.

**DOCUMENTATION READY** means the reviewed documentation commit passes local publication/link/whitespace checks. **RELEASE READY** additionally requires complete hosted CI on the exact final commit, matching verified artifacts and resolution/review of applicable outstanding release gates. Documentation preparation establishes neither a published release nor validated real uninstall behavior.
