# Scanner fixtures

Fixtures are generated in uniquely named temporary directories by the test suite rather than storing copies of installed applications or personal inventory data in the repository.

Tests include native Info.plist bundles, local store receipt presence, Homebrew receipts/configuration and multiple kegs, PKG query output, MacPorts installed output, modern/legacy Nix JSON, Setapp framework markers, Steam KeyValues manifests, and legacy/recognized modern Toolbox generated launchers. Health/removal fixtures exercise missing payloads, retained registrations, historical receipts, conflicts and changed identities. Production adapter tests inject fake manager effects/openers and recoverable moves confined to disposable fixture trees; they do not invoke real manager removal, Finder Trash or privileged-helper registration.

These are representative adapter fixtures, not proof of current live-provider compatibility or destructive safety. See [source support](../Docs/SOURCE_SUPPORT.md) and [verification](../Docs/VERIFICATION.md) for boundaries.
