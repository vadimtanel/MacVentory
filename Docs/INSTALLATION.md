# Installing Macventory 1.1.0

**v1.1.0 / build 108 was released on 27 October 2026.** Download the files below from the [official v1.1.0 release](https://github.com/vadimtanel/MacVentory/releases/tag/v1.1.0), or install through the official Homebrew Tap. [All releases](https://github.com/vadimtanel/MacVentory/releases) includes earlier versions.

## Compatibility

- Primary distribution: Apple Silicon, `arm64`. M1–M5 are intended targets, not individually tested models.
- Configured minimum: macOS **13.0**, consistent in the package, app plist and Xcode app/helper targets. Minimum-OS runtime remains unverified.
- Recorded local runtime: Apple M4 Pro on macOS 27.0.1. Hosted arm64 CI is separate evidence; see [verification](VERIFICATION.md).
- Intel/universal binaries and Intel runtime support are not advertised as verified release targets.
- End-user Macs do not need SwiftPM, Xcode or development files. Tests require a macOS 14+ host; full Xcode is needed for Xcode/XCUITest development checks.

## Published v1.1.0 assets

All four files are available on the [v1.1.0 release page](https://github.com/vadimtanel/MacVentory/releases/tag/v1.1.0):

| Filename | Purpose |
|---|---|
| [Macventory-1.1.0-arm64.dmg](https://github.com/vadimtanel/MacVentory/releases/download/v1.1.0/Macventory-1.1.0-arm64.dmg) | Recommended visual drag-to-Applications installer |
| [Macventory-1.1.0-arm64.zip](https://github.com/vadimtanel/MacVentory/releases/download/v1.1.0/Macventory-1.1.0-arm64.zip) | Alternative self-contained app bundle |
| [Macventory-1.1.0-arm64.sha256](https://github.com/vadimtanel/MacVentory/releases/download/v1.1.0/Macventory-1.1.0-arm64.sha256) | SHA-256 entries for DMG, ZIP and source archive |
| [Macventory-1.1.0-source.tar.gz](https://github.com/vadimtanel/MacVentory/releases/download/v1.1.0/Macventory-1.1.0-source.tar.gz) | Reviewed source inputs; not an installable app |

Use artifacts and checksums from the same release. The released app metadata is **1.1.0 / build 108**.

## DMG installation

1. Download the arm64 DMG and checksum file from the same official published release.
2. [Verify the checksum](#sha-256-verification) before opening the image.
3. Open the DMG (`Macventory-1.1.0-arm64.dmg`).
4. Drag **Macventory.app** onto the **Applications** shortcut.
5. Eject the image and launch Macventory from Applications or Spotlight.

The compressed, read-only image contains the complete app, an Applications symlink and a visual guide. No privileged installer, package-manager operation or post-install script is needed. Installing or scanning does not activate the bundled MacPorts helper. Privileged MacPorts removal needs trusted matching signing and separate OS approval; the default ad-hoc build cannot use that route. See [uninstall support](UNINSTALL.md).

## ZIP installation

1. Download the arm64 ZIP and checksum file from the same official published release.
2. Verify and extract the ZIP (`Macventory-1.1.0-arm64.zip`).
3. Move **Macventory.app** into Applications, then launch it.

Keep the whole app bundle intact. Copy it into Applications before use rather than running from the mounted image.

## Homebrew installation

With Homebrew already installed:

```sh
brew install --cask vadimtanel/macventory/macventory
```

The fully qualified name identifies the project's Cask in its separate [Homebrew Tap](https://github.com/vadimtanel/homebrew-macventory). Homebrew obtains the official DMG and checks its Cask SHA-256. If needed, add the Tap explicitly:

```sh
brew tap vadimtanel/macventory
brew install --cask vadimtanel/macventory/macventory
```

The official [Cask](https://github.com/vadimtanel/homebrew-macventory/blob/main/Casks/macventory.rb) offers **1.1.0** and matches the published DMG checksum (verified 28 October 2026). Run `brew update` if local metadata still shows an older version. Homebrew does not make an ad-hoc signed app notarized or bypass Gatekeeper.

## Updating an existing installation

Quit Macventory normally before replacing it. For a manual installation, verify the new release's DMG/ZIP and replace the existing app in Applications. Avoid retaining another copy that could cause confusion about which version is running. Launch the replacement and inspect **About Macventory**; v1.1.0 is build 108. Refresh inventory after updating. Replacement does not require clearing the cache or user data.

For a Homebrew-managed installation:

```sh
brew update
brew upgrade --cask vadimtanel/macventory/macventory
brew info --cask vadimtanel/macventory/macventory
```

Use the manager's update path for its registered installation. A missing-app warning can mean the manager still records an app that was moved or removed; inspect the exact path/registration rather than deleting receipts. Updating Macventory does not update other software in its inventory.

## SHA-256 verification

Download the checksum file from the same official release. An optional Terminal check for a single asset is:

```sh
shasum -a 256 Macventory-1.1.0-arm64.dmg
```

Compare the entire hash with its entry in `Macventory-1.1.0-arm64.sha256`. Substitute the ZIP or source filename to check those files. If you downloaded **all three listed artifacts** into the same directory, check every entry together:

```sh
shasum -a 256 -c Macventory-1.1.0-arm64.sha256
```

Each entry must report `OK`. A complete-file check with only the DMG downloaded reports the other artifacts missing; compare the individual DMG hash instead. On a mismatch, stop and obtain matching files from the official release. Checksums detect a mismatch relative to the checksum file; they do not independently authenticate its publisher.

## Code signing, first launch and Gatekeeper

The default package is **ad-hoc signed and not Apple-notarized**. The signature seals bundle integrity; it does not establish Developer ID publisher identity or Apple's notarization assessment. Gatekeeper evaluates downloaded software independently. No Developer ID, notarized distribution or universal first-launch success is claimed.

Attempt to open the app and read the warning. If you independently trust the official source and checksum, macOS may offer **System Settings → Privacy & Security → Open Anyway**, followed by normal confirmation. This is the user's explicit per-app exception, not an automatic operation. Availability depends on macOS and organizational policy. Do not bypass malware/damaged-app warnings, clear quarantine programmatically or disable Gatekeeper/SIP. See [Apple's supported procedure](https://support.apple.com/102445).

## Troubleshooting and verification limits

| Symptom | Check |
|---|---|
| A download link fails | Use the official v1.1.0 release page above and select the matching asset. Check connectivity and retry. |
| Homebrew offers an older version | Run `brew update`, inspect `brew info`, and check the official Cask version. |
| About shows an older version | Quit normally and confirm you opened the replacement in Applications, rather than another copy or mounted image. |
| Gatekeeper blocks launch | Read the actual warning and supported procedure above; signatures/checksums are different checks. Managed policy can prevent an exception. |
| Unknown, missing apps or historical receipts | Refresh and inspect source evidence. Missing metadata or retained registration does not prove removal or authorize cleanup. |
| Access denied | Review the named failed check and macOS privacy access yourself. Macventory cannot grant itself access. |

The released commit passed native/GUI CI and packaging/artifact validation. Manual macOS VM testing is complete, as confirmed by the maintainer. These checks do not certify every provider, macOS 13 runtime, Intel execution or every Gatekeeper policy. See [verification](VERIFICATION.md), [source support](SOURCE_SUPPORT.md), [uninstall limits](UNINSTALL.md) and the [release process](RELEASING.md).
