# v1.1.0 documentation and release-preparation review

**Historical report.** v1.1.0 was released on 27 October 2026 with passing native/GUI CI. See [current verification](VERIFICATION.md) for completed checks and manual VM testing. Failed/pending checks, branch state and proposed next steps below apply only to the dated development pass.

Review date: **26 October 2026**, Asia/Jerusalem. Scope: main Macventory repository only. Starting branch/upstream: `main` / `origin/main`; starting local and advertised remote SHA: `a5a66efcaf2f1b06c3f32bb104e6125239f831c9`. The initial tracked/untracked working tree was clean. The remote was checked read-only; no fetch/rebase/reset was needed.

Candidate metadata is already **1.1.0 / build 108**; configured minimum is macOS **13.0**. No version bump is part of this review. v1.1.0 is upcoming; the tag/release and four planned artifacts are owner-controlled later steps. Pushing the documentation commit requires separate approval.

## Complete documentation inventory

All **34 tracked Markdown files** at the starting commit were read and reviewed. The table lists every file and its disposition. This new review record is the 35th Markdown document and is also checked before commit. “Historical” means evidence is retained for its named build/pass, not relabeled as v1.1.0 or represented as new verification.

| File | Disposition |
|---|---|
| [README.md](../README.md) | Updated product/version, upcoming download status, installation, health, removal and verification claims; screenshots/branding/credits retained |
| [CHANGELOG.md](../CHANGELOG.md) | Added upcoming v1.1.0 changes since public v1.0.0 with five requested categories; retained local milestone text and clarified public baseline |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | Added development/documentation checks and exact-commit CI requirements |
| [SECURITY.md](../SECURITY.md) | Updated current-version/helper wording, data/history/network scope and current trust/validation links |
| [SPEC.md](../SPEC.md) | Updated current product scope, columns/health/settings/compatibility and authoritative v1.1.0 clarification; retained build-specific amendments |
| [Design/Branding/README.md](../Design/Branding/README.md) | Reviewed; provenance, hashes and resource dependencies retained unchanged |
| [Docs/ARCHITECTURE.md](ARCHITECTURE.md) | Updated health, identity persistence, explicit effects/network boundary and helper architecture |
| [Docs/CHECKPOINT.md](CHECKPOINT.md) | Added historical-log notice and current-state links; recorded checkpoints unchanged |
| [Docs/CI.md](CI.md) | Added actual workflow/scenario/artifact contract and dated starting-commit evidence; original build-102 report retained |
| [Docs/CLEANUP.md](CLEANUP.md) | Historical cleanup/resource audit reviewed and retained unchanged |
| [Docs/COMPACT-LAYOUT.md](COMPACT-LAYOUT.md) | Historical display investigation reviewed and retained unchanged |
| [Docs/GIT_INTEGRATION.md](GIT_INTEGRATION.md) | Dated first-commit proposal reviewed and retained unchanged; current Git procedure is in RELEASING |
| [Docs/GUI_QA.md](GUI_QA.md) | Added historical-evidence notice; original GUI checks unchanged |
| [Docs/HEADER-LOADER-AND-POINTER.md](HEADER-LOADER-AND-POINTER.md) | Historical diagnostic investigation reviewed and retained unchanged |
| [Docs/HEADER-PROXIES.md](HEADER-PROXIES.md) | Historical diagnostic investigation reviewed and retained unchanged |
| [Docs/IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) | Dated original implementation plan reviewed and retained unchanged |
| [Docs/INSTALLATION.md](INSTALLATION.md) | Updated Apple Silicon, DMG/ZIP/Homebrew/update/checksum instructions, planned assets and signing/Gatekeeper/runtime limits |
| [Docs/INVENTORY_AUDIT.md](INVENTORY_AUDIT.md) | Added historical read-only-audit notice; observations/counts unchanged |
| [Docs/PUBLICATION_REVIEW.md](PUBLICATION_REVIEW.md) | Dated original publication review reviewed and retained unchanged; not the current manifest count |
| [Docs/RELEASING.md](RELEASING.md) | Replaced obsolete first-publication workflow with final-docs → version → full CI → assets → exact-SHA tag → owner release → separate Tap sequence |
| [Docs/SELECTION_TRACE_HANDOFF_VALIDATION.md](SELECTION_TRACE_HANDOFF_VALIDATION.md) | Dated diagnostic contract/evidence reviewed and retained unchanged; not a final selection-test pass |
| [Docs/SETTINGS.md](SETTINGS.md) | Documented existing default-off personal suggestions and independent health/cleanup authority |
| [Docs/SOURCE-HEADER.md](SOURCE-HEADER.md) | Historical diagnostic investigation reviewed and retained unchanged |
| [Docs/SOURCE_SUPPORT.md](SOURCE_SUPPORT.md) | Updated current-state entry point; distinguished discovery from removal and preserved provider evidence limits |
| [Docs/TECHNICAL_CORRECTIONS.md](TECHNICAL_CORRECTIONS.md) | Corrected current Homebrew queries, persistence, uninstall/toolchain and optional network behavior |
| [Docs/UNIFIED_UNINSTALL_AND_HEALTH.md](UNIFIED_UNINSTALL_AND_HEALTH.md) | Explicit earlier-pass report reviewed and retained unchanged |
| [Docs/UNINSTALL.md](UNINSTALL.md) | Added coherent current workflow/matrix, authorization/outcome/data boundaries; original build notes retained under historical divider |
| [Docs/UNINSTALL_EXECUTION_LEVELS.md](UNINSTALL_EXECUTION_LEVELS.md) | Explicit earlier-pass report reviewed and retained unchanged |
| [Docs/UNINSTALL_FINAL_AUDIT.md](UNINSTALL_FINAL_AUDIT.md) | Dated security/correctness findings reviewed and retained unchanged; no retroactive deployment/CI pass claimed |
| [Docs/UNINSTALL_FOCUSED_VALIDATION.md](UNINSTALL_FOCUSED_VALIDATION.md) | Dated synthetic results/disposable verification plan reviewed and retained unchanged; planned real operations remain unexecuted |
| [Docs/VERIFICATION.md](VERIFICATION.md) | Added current evidence categories, version and final-commit CI boundary; old results preserved as historical |
| [Docs/XCUITEST-INVESTIGATION.md](XCUITEST-INVESTIGATION.md) | Dated hosted failure investigation reviewed and retained unchanged |
| [Fixtures/README.md](../Fixtures/README.md) | Updated representative modern/health/effect-boundary coverage; no real removal claim |
| [Resources/DMG/README.md](../Resources/DMG/README.md) | Reviewed existing installer layout/provenance and retained unchanged |

Updated files are the **18 existing documents** marked updated/added notice above, plus this new review record (**19 documentation files** total). All other tracked inputs remain unchanged.

## Major corrections and evidence

- Current headings/download instructions now target upcoming v1.1.0, with durable latest/releases links for available downloads and explicitly future v1.1.0 filenames/page. Historical v1.0.0 notes, fixtures, validation counts and old package identifiers remain unchanged.
- README/current guides describe seven sortable fields including Status, Attention Required, missing Homebrew apps/current registrations, historical PKG receipts and separate physical-copy identity. Health is separate from ownership/removal authority; discovery performs no repair.
- Current uninstall guidance no longer incorrectly assigns all formulae/MacPorts/Nix/Steam/Store/PKG records the earlier guided-only behavior or restricts supported casks to exactly one app artifact. Eligibility and supported modes are explicit; Setapp/Toolbox remain guided where targeted integration is unavailable.
- Existing application management and Leftover Data are described without calling them new since the public v1.0.0 baseline. Selection safeguards, separate path review, default-off personal suggestions, partial scans, already-missing targets and unknown outcomes remain explicit.
- Architecture no longer claims that every app action has no effects, no helper or no network. Inventory remains local/read-only; confirmed management effects and user-requested official-link HEAD/browser access have separate boundaries. The narrow privileged MacPorts route requires signing/OS authority unavailable in ad-hoc builds.
- Requirements distinguish configured macOS 13.0, recorded M4 Pro/macOS 27.0.1 runtime, macOS 14+ test hosts, primary arm64 artifacts and unverified Intel/universal/minimum-OS runtime. Ad-hoc integrity is distinct from Developer ID/notarization and Gatekeeper acceptance.
- Release instructions require full hosted CI on the exact final documentation/source SHA. Manual default `isolated`, native-only success and packaging-only runs cannot establish that result. Tag/release/Tap synchronization follow artifact verification; documentation preparation does not perform them.

Claims were checked against `Resources/Info.plist`, Package.swift, Xcode target metadata, current scanners/health/sorting/preparation/adapters, official-documentation resolver, CI workflows, sequence verifier and unchanged packaging/artifact/publication scripts. The public v1.0.0 tag and changes since it were inspected locally. No source/dependency/script/workflow/signing/Cask change is included.

## Validation record

- Unchanged `python3 scripts/review-publication.py`: **147 publication inputs; 0 findings**. Generated manifests remain ignored under `build/`; no generated file enters the commit.
- All **19 changed Markdown files** parsed successfully with the installed RDoc Markdown parser; manual content/diff review and fence checks supplement parsing.
- All **35 Markdown files** checked for local links/assets and heading fragments: **150 local references, 5 heading fragments and 1 HTML media reference; zero broken or unpublished local targets**. The explicitly upcoming remote v1.1.0 page is not represented as an existing download.
- Metadata check confirms **1.1.0 / build 108 / macOS 13.0**; package/Xcode deployment targets and separate macOS 14 test-host target agree. Current-state version references are distinguished from historical/fixture versions.
- Historical bodies in the changelog, uninstall/verification/CI logs and notice-only historical reports are preserved. The complete inventory matches all 34 original tracked Markdown paths.
- `git diff --check` passes. All 19 intended changes are documentation; application source, dependencies, scripts, workflows, signing configuration, Cask files, LICENSE/NOTICE, branding and screenshots are unchanged. Publication scans report no developer-specific private paths or credential-shaped content; these checks supplement manual review and are not a proof that every possible secret can be detected.

No application, package, process or user-data destructive test is run. No privileged helper is registered/activated and no release artifacts are created by this task.

## Hosted CI and remaining limitations

The final read-only check of [run 40309598774](https://github.com/vadimtanel/MacVentory/actions/runs/40309598774), attempt 1, for starting SHA `a5a66efcaf2f1b06c3f32bb104e6125239f831c9` shows **overall failure**. Native passed, including hosted Xcode units, packaging and artifact validation. UI failed actual-count/order verification and final outcome reporting, even though GitHub's summaries list primary XCUITest and header diagnostic steps as successful. These summaries do not establish a complete 16-case pass or explain the mismatch; raw logs/xcresults need separate inspection. No production/UI repair is part of this documentation task, and this run cannot validate the subsequent commit.

The new documentation commit is not pushed and has **no complete hosted CI validation**. Older reports include failing/partial GUI runs and local synthetic passes; none is silently promoted to final-commit success. The original selection regression must be judged from actual final-run evidence, not from trace-transport corrections or compilation alone.

Real Homebrew/MacPorts/Nix removal, native Trash/restoration, real Force Quit, Store/vendor/Steam completion, signed-helper authentication/authorization/lifecycle/update, macOS 13 runtime, clean-machine Gatekeeper and full VoiceOver remain unverified. Current Steam protocol/client behavior also needs revalidation. Provider layouts/interfaces can change. These are limitations and applicable release gates, not implied successful checks. Developer ID/notarization are not claimed or required for ordinary ad-hoc packaging; privileged deployment has separate trusted-signing requirements.

**DOCUMENTATION READY** is a local documentation/publication result. **RELEASE READY is not established.** The owner must separately approve pushing, obtain full final-commit CI and verified matching artifacts, and review/resolve applicable outstanding gates before tagging/publishing. Commit identity and the exact changed-file list are reported after the commit, avoiding a self-referential SHA in its own content.
