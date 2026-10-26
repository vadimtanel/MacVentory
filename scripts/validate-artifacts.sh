#!/bin/bash
# Validate project-owned outputs without installing or launching an application.
set -euo pipefail
cd "$(dirname "$0")/.."
app="$PWD/build/Macventory.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
prefix="$PWD/artifacts/Macventory-$version-arm64"
for executable in Macventory MacventoryPrivilegedHelper; do
  [[ "$(/usr/bin/lipo -archs "$app/Contents/MacOS/$executable")" == arm64 ]]
done
/usr/bin/codesign --verify --strict --verbose=2 "$app/Contents/MacOS/MacventoryPrivilegedHelper"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app"
/usr/bin/hdiutil verify "$prefix.dmg"
(cd artifacts && /usr/bin/shasum -a 256 -c "Macventory-$version-arm64.sha256")
python3 - <<'PY'
import hashlib
import json
from pathlib import Path
import plistlib
import tarfile
import zipfile

root = Path.cwd()
app = root / 'build/Macventory.app'
# Signing/integrity alone accepts binaries carrying private compiler paths.
# Inspect both shipped executables, independently of the stripping implementation.
for name in ('Macventory', 'MacventoryPrivilegedHelper'):
    data = (app / 'Contents/MacOS' / name).read_bytes()
    if any(marker in data for marker in (b'/Users/', b'/var/folders/', str(root).encode())):
        raise SystemExit(f'Private build path remains in packaged executable: {name}')
expected = plistlib.loads((root / 'Resources/Info.plist').read_bytes())
actual = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
for key in ('CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion'):
    assert actual[key] == expected[key], (key, actual[key], expected[key])
version = actual['CFBundleShortVersionString']
with zipfile.ZipFile(root / f'artifacts/Macventory-{version}-arm64.zip') as archive:
    assert archive.testzip() is None
    for path in app.rglob('*'):
        if path.is_file():
            member = 'Macventory.app/' + path.relative_to(app).as_posix()
            assert archive.read(member) == path.read_bytes(), member
manifest = json.loads((root / 'build/publication-manifest.json').read_text())
with tarfile.open(root / f'artifacts/Macventory-{version}-source.tar.gz') as archive:
    assert set(archive.getnames()) == {row['path'] for row in manifest}
    for row in manifest:
        data = archive.extractfile(row['path']).read()
        assert hashlib.sha256(data).hexdigest() == row['sha256'], row['path']
print(f"Validated arm64 {version}/build{actual['CFBundleVersion']}: signature, DMG integrity, checksums, ZIP bytes and source manifest.")
PY
