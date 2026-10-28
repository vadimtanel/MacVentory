# Macventory release process

Official repository: [vadimtanel/MacVentory](https://github.com/vadimtanel/MacVentory). Release branch: `main`.

## Published v1.1.0

**v1.1.0 / build 108 was released on 27 October 2026.** The [stable GitHub Release](https://github.com/vadimtanel/MacVentory/releases/tag/v1.1.0) and tag point to `54bb40270bf8309ce454cfb0cf73c80afed07ef9`. Its [complete CI run](https://github.com/vadimtanel/MacVentory/actions/runs/40535995628) passed native and UI jobs, including all 17 primary GUI cases, diagnostics, packaging and artifact validation. Manual VM testing is complete, as confirmed by the maintainer. See [verification](VERIFICATION.md).

The four published assets are `Macventory-1.1.0-arm64.dmg`, `Macventory-1.1.0-arm64.zip`, `Macventory-1.1.0-arm64.sha256` and `Macventory-1.1.0-source.tar.gz`. The official [Homebrew Cask](https://github.com/vadimtanel/homebrew-macventory/blob/main/Casks/macventory.rb) also offers 1.1.0 (checked 28 October 2026).

Documentation corrections after publication do not require another app-version bump. Keep **1.1.0 / 108** for this documentation update. Preserve the existing release tag, downloads and source archive; a later documentation commit is not the source of those published binaries.

## Preparing the next release

1. Finalize source and public documentation together: README, changelog, installation, source support, uninstall/security and verification. Clearly date historical reports and link them to current status. Preserve LICENSE, NOTICE, branding and approved screenshots.
2. Set the intended app version/build in `Resources/Info.plist`; verify app/helper deployment targets in Package.swift and the Xcode project. The v1.1.0 reference values are `1.1.0`, `108`, `13.0`. Configured deployment targets are distinct from runtime verification.
3. Run publication, Markdown/link and whitespace checks. Review only the intended changes and retain the generated manifest under ignored `build/`.

```sh
python3 scripts/review-publication.py
git diff --check
```

Require zero publication findings. Do not discard unrelated work, rewrite shared history or force-push.

## Complete CI on the candidate commit

Use [Build and test Macventory](../.github/workflows/ci.yml) on the exact intended SHA. Reuse the push/PR run when it covers the full suite; manual dispatch defaults to `isolated`, so select `full` for complete verification. Confirm actual checked-out SHA and scenario in the evidence.

Require successful native and UI jobs:

- SwiftPM build/fixture tests, Xcode app build, all test-target compilation and isolated hosted Xcode unit tests.
- arm64 app/ZIP/DMG/source packaging and artifact validation.
- All **17 primary GUI cases**, with no missing, skipped or failed cases, count/order verification, xcresult export, header comparison, independent pointer diagnostics and final reporting.

The workflow pins `macos-26` arm64 and Xcode 26.5 and checks the toolchain. A diagnostic subset, native-only result or [packaging-only workflow](../.github/workflows/package.yml) cannot substitute for full CI. See [CI details](CI.md).

A later candidate commit changes the source-archive inputs; validate that new candidate before issuing new artifacts. A documentation correction after an existing release does not retroactively invalidate the successful release run. Record manual/runtime checks separately, with their environment and actual scope. Synthetic tests do not establish every real provider effect or privileged-helper lifecycle.

## Packaging and publication

The local equivalents of the CI packaging/validation steps are:

```sh
bash scripts/package-release.sh
bash scripts/validate-artifacts.sh
```

These scripts can replace local outputs under `build/` and `artifacts/`; they do not publish anything. The validator checks arm64 app/helper architecture, signatures, version/build agreement, private compiler-path absence, DMG integrity, every checksum entry, ZIP bytes and exact reviewed source-manifest membership/hashes. Retain logs and hashes tied to the candidate SHA. Never mix files from different builds.

Review DMG layout, ZIP extraction and applicable runtime scenarios in a controlled environment. Keep ad-hoc signing and source-specific limitations explicit: Developer ID/notarization is not supplied by ordinary packaging, and privileged MacPorts removal requires separate trusted signing and OS authorization. Use the supported [Gatekeeper guidance](INSTALLATION.md#code-signing-first-launch-and-gatekeeper).

With the maintainer's publication authorization, create the new version tag at the validated commit and publish its reviewed release notes and four matching assets. Do not replace or move an existing release tag. GitHub-generated source archives are distinct from the reviewed source asset. Update public documentation to released status as part of publication, then confirm the release page and download links actually exist.

Finally, verify that the separate [Homebrew Tap](https://github.com/vadimtanel/homebrew-macventory) has synchronized the new version and DMG checksum. Record its actual availability; installation instructions should not continue describing a synchronized release as pending.
