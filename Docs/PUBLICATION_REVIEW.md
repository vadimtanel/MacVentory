# Pre-publication review

**Historical report.** v1.1.0 was released on 27 October 2026 with passing native/GUI CI. See [current verification](VERIFICATION.md) for completed checks and manual VM testing. Failed/pending checks, branch state and proposed next steps below apply only to the dated development pass.

23 October 2026. Local review only; no files were uploaded. Exact proposed inputs and SHA-256 values are in ignored `build/publication-manifest.json`, generated with `scripts/review-publication.py`. Run again after any edit.

## Scope and findings

- Reviewed application/core code, test fixtures, project/build/CI files, docs, artwork and public screenshots. Pattern checks look for credential-shaped literals, developer-specific paths, unreviewed screenshots and broken local Markdown/image references. This is a practical review, not a guarantee that arbitrary secrets can always be detected.
- Intentional `/Users/private/...` strings in diagnostics-redaction tests are synthetic fixtures. Creator name, copyright, public profile/repository links and bundle identifier are public attribution.
- No real inventory JSON, private diagnostics or personal application list is included. Prior screenshots and previous document versions containing local details were preserved in ignored `build/private-review/`, rather than published. Local runtime/packaging/test evidence remains ignored.
- Exactly five public PNG screenshots show the real native app in isolated demo mode and the final native Finder installer window. Inventory captures show fictional records only; no desktop, terminal, Dock, notifications or unrelated windows. Visual inspection confirmed readable text, branding and no private paths; PNG text/EXIF metadata checks found no such chunks. A native macOS capture indicator may appear in the title bar; screenshots were not recreated.
- Original owner-provided PNGs are preserved; ICNS remains unchanged. Toolbar image is a reproducible derivative of that supplied artwork. No downloaded third-party profile logos, fonts or other asset licenses were added. About links use Apple-provided SF Symbols at runtime with descriptive text. No external Swift package dependency. Native AppKit installer background and fixed Finder layout metadata add no runtime dependency or third-party artwork. Binary layout is checked for private path strings.
- Apache LICENSE is unchanged and matches remote/official text. NOTICE provides copyright and attribution without additional restrictions. See [Git integration](GIT_INTEGRATION.md).
- .gitignore protects generated outputs, SwiftPM/Xcode state, logs, local snapshots/diagnostics, environment/credential files and editor state. Source, required fixtures/scripts/workflows, branding and approved screenshots remain visible.

Release binary review found developer build paths in SwiftPM debug-symbol references. Release bundling now strips debug references from the copied executable before ad-hoc signing; post-strip checks found zero developer home paths. Debug builds remain local.

## Cleanup

Retained legitimate architecture/specification/checkpoint/test/build documentation. Archived old private captures, superseded local reports and duplicate original branding note under ignored build/. No broad refactoring or unrelated cleanup. No installed applications/packages/user data removed or modified; real cache not cleared.

## Publication gates

The manifest is the proposed first application commit, not a staged commit. Owner approval remains required for staging/committing, remote configuration/history changes, pushing, metadata edits and releases. Full Xcode/XCUITest, actual VoiceOver, minimum-OS/clean-machine distribution and controlled destructive uninstall checks remain open. Intel is optional. This is a local review candidate, not a fully verified public release.

##1.0.0 reviewed set

Before cleanup, the reviewed set had 94 inputs: unchanged tracked LICENSE and 93 proposed additions. The current set below supersedes that baseline. Includes source/tests/fixtures, project/CI/build scripts, installer layout/background, five safe screenshots and professional English documentation. All source-archive bytes match the regenerated local manifest. Previous0.1.0 binaries/packages are preserved under ignored build/pre-1.0.0. No installed application was copied over or removed. Pattern checks found zero findings, supplemented by manual screenshot/resource review and final-binary path checks.

## Cleanup revision — current publication set

The earlier 94-input proposal is superseded by 85 reviewed files (84 additions plus unchanged tracked LICENSE). Ten reproducible iconset PNG intermediates are archived privately and ignored; CLEANUP.md adds one legitimate audit report. Source packaging reads the manifest explicitly instead of sweeping directories. 17 ignore probes pass, all 85 intended files stay public, no tracked ignored file, no link/privacy-pattern findings. App source/tests/official artwork/shipped resources unchanged. No additional agent scratch file or proven dead code removed. Root QA logs preserved privately; three unreferenced Finder metadata files deleted.
