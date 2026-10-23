# Installation layout

The distribution image contains two visible items: Macventory.app and a symlink to /Applications. LICENSE/NOTICE are inside the signed application resources. No privileged installer or install script is used.

`background.png` is drawn using native AppKit/system fonts by `scripts/make-dmg-background.swift`; no third-party artwork or fonts. The application build embeds it as Contents/Resources/DMGBackground.png so the disk needs no extra visible background folder.

`FinderLayout` is packaging metadata copied to the disk root as .DS_Store. It preserves a native Finder allocator and specifies a 640×520 window, 96-point icons at (170,195)/(470,195), icon view and a native alias to the bundled background. Its target is the generic Macventory volume/app resource, without a developer home path. Retaining a fixed template avoids adding a runtime packaging dependency or UI-scripting requirement. Finder chrome can follow the viewer's preferences. The final read-only image must be visually checked after template changes.

The layout is metadata rather than application code. Apple does not document .DS_Store as a stable public API; Finder layout compatibility is a distribution limitation, while copying the app remains a standard filesystem operation. Background generation example:

```sh
swift scripts/make-dmg-background.swift Resources/DMG/background.png
```
