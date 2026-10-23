#!/usr/bin/env python3
"""Read-only publication input audit. Never stages, commits, uploads or reads ignored evidence."""
import hashlib
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
raw = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT)
paths = sorted(set(p for p in raw.decode().split('\0') if p))
errors = []
manifest = []
screenshots = {'macventory-inventory-light.png', 'macventory-inventory-dark.png', 'macventory-settings.png', 'macventory-about.png', 'macventory-installer.png'}
# Match credential-shaped literals, not ordinary variable names or safety documentation.
patterns = [r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', r'gh[pousr]_[A-Za-z0-9]{30,}', r'github_pat_[A-Za-z0-9_]{40,}', r'AKIA[A-Z0-9]{16}', r'sk-[A-Za-z0-9]{32,}']
for relative in paths:
    path = ROOT / relative
    if path.is_symlink():
        errors.append(f'Unexpected publication symlink: {relative}')
        continue
    data = path.read_bytes()
    manifest.append({'path': relative, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
    if relative.startswith(('build/', 'artifacts/', '.build/')) or relative.endswith('-log.txt'):
        errors.append(f'Generated/private input: {relative}')
    if relative.startswith('Docs/Screenshots/') and path.name not in screenshots:
        errors.append(f'Unreviewed screenshot: {relative}')
    if relative == 'Resources/DMG/FinderLayout':
        for marker in ['/Users/', '/var/folders/']:
            if marker.encode() in data or marker.encode('utf-16be') in data:
                errors.append(f'Private path in Finder layout: {relative}')
    if b'\0' in data:
        continue  # Binary assets require the separate visual/resource review.
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        continue
    for pattern in patterns:
        if re.search(pattern, text):
            errors.append(f'Credential-shaped content: {relative}')
    if re.search(r'/Users/(?!private(?:/|\b))[A-Za-z0-9_.-]+/', text) or re.search(r'/var/folders/[a-z0-9]+/', text):
        errors.append(f'Developer-specific absolute path: {relative}')
    if path.suffix == '.md':
        targets = re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', text) + re.findall(r'<img[^>]+src=["\x27]([^"\x27]+)', text)
        for target in targets:
            target = target.strip('<>').split('#')[0]
            if not target or re.match(r'[a-zA-Z][a-zA-Z0-9+.-]*:', target):
                continue
            if not (path.parent / target).exists():
                errors.append(f'Broken local link in {relative}: {target}')
output = ROOT / 'build'
output.mkdir(exist_ok=True)
(output / 'publication-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(output / 'publication-manifest.txt').write_text('\n'.join(row['path'] for row in manifest) + '\n')
for error in errors:
    print(error)
print(f'{len(manifest)} publication inputs; {len(errors)} findings. Manifest: build/publication-manifest.json')
print('Pattern/link checks supplement manual review; they do not prove absence of every possible secret.')
sys.exit(bool(errors))
