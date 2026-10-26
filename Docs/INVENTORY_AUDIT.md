# Inventory comparison — privacy-safe summary

**Historical v1.0.0 read-only audit.** Counts/timings below describe that development-machine run, not a new scan of the v1.1.0 candidate. See [current verification](VERIFICATION.md) for release status. Read-only inventory accuracy is separate from uninstall safety.

The current read-only development-machine audit reproduced 84 merged records:27 native bundles,55 Homebrew formula names/56 kegs,7 casks and 3 overlapping PKG discoveries. The default UI hid one system record, giving83 shown. Independent validation passed 476 checks, including paths, bundle/package versions, physical identity, all reported logical footprints and receipt timestamps.25 Spotlight usage observations were available outside the restricted CLI context.

The first-commit materials deliberately omit personal software names, exact local payload paths and raw snapshots. Detailed machine observations are private local evidence, not publication inputs. The current pass repeated all 476 independent checks with zero failures, including every reported logical footprint, and all three read-only live integration tests. Scan duration was 3.31 seconds; a synthetic1000-row filter/name-sort probe averaged1.44 ms (maximum3.09 ms over 25 runs). These measurements describe this machine/run only.

| Source | Live coverage |
|---|---|
| Native bundles / direct classification | Compared to independent enumeration and metadata. Arbitrary locations outside supported/configured roots are not exhaustive. |
| Homebrew casks | Current recognized receipt mappings matched the read-only installed list and merged with native payloads. |
| Homebrew formulae | Installed names/kegs/versions/timestamps compared. Separate keg versions retained. |
| PKG | Existing receipt payload matching compared; receipt age/orphan state limits certainty. |
| App Store | No positive local receipt example; positive/negative synthetic fixtures only. |
| MacPorts, Nix, Setapp, Steam, Toolbox | Providers absent on the development Mac; recognized formats tested with fixtures only. |

Duplicate-looking names can be separate paths/inodes or package versions. App self-updates may make bundle versions newer than manager receipts; both facts retain provenance. Installation events are not filesystem creation, missing usage is not unused, and payload footprint is not reclaimable space. See SOURCE_SUPPORT.md for adapter limits.
