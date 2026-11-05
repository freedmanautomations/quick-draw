#!/usr/bin/env python3
"""Export only the reviewed file list; no publishing, Git history or user settings."""
from pathlib import Path
import hashlib, json, plistlib, stat, subprocess, zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE_FILES = [
    '.gitignore', 'README.md', 'CONTEXT.md', 'LICENSE', 'PRIVACY.md', 'SECURITY.md', 'CONTRIBUTING.md',
    'build.py', 'verify.py', 'scripts/icon.swift', 'scripts/release.py',
    'Sources/Core.swift', 'Sources/Interface.swift', 'Sources/Host.swift', 'Sources/Entry.swift',
    'Tests/SelfTest.swift', 'Tests/InterfaceChecks.swift', 'Tests/CheckMain.swift',
]
APP_FILES = ['Contents/Info.plist', 'Contents/MacOS/QuickDraw', 'Contents/Resources/QuickDraw.icns', 'Contents/_CodeSignature/CodeResources']

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def checked(base, name):
    path = base / name
    require(path.is_file() and not path.is_symlink(), 'Not a regular release file')
    require(path.resolve().is_relative_to(base.resolve()), 'Release path outside source root')
    for parent in path.parents:
        if parent == base:
            break
        require(not parent.is_symlink(), 'Symlink directory refused')
    return path

def archive(output, base, prefix, names):
    hashes = {}
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as zipped:
        for name in names:
            path = checked(base, name)
            data = path.read_bytes()
            entry = zipfile.ZipInfo(prefix + '/' + name, date_time=(2026, 1, 1, 0, 0, 0))
            entry.create_system = 3
            mode = 0o755 if name == 'Contents/MacOS/QuickDraw' else 0o644
            entry.external_attr = (stat.S_IFREG | mode) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            zipped.writestr(entry, data)
            hashes[name] = hashlib.sha256(data).hexdigest()
    return hashes

def main():
    app = ROOT / '.build/Quick Draw.app'
    actual = {str(p.relative_to(app)) for p in app.rglob('*') if p.is_file()}
    require(actual == set(APP_FILES), 'Unexpected app bundle content')
    require(not any(p.is_symlink() for p in app.rglob('*')), 'Symlink app content refused')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True, capture_output=True)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    require(info['CFBundleIdentifier'] == 'org.quickdraw.launcher' and info['LSUIElement'], 'Unexpected app identity')
    receipt = json.loads((ROOT / '.build/build.json').read_text())
    current = {name: hashlib.sha256(checked(ROOT, name).read_bytes()).hexdigest() for name in SOURCE_FILES}
    require(current == receipt['sourceHashes'], 'Source changed since the checked build')
    require(hashlib.sha256((app / 'Contents/MacOS/QuickDraw').read_bytes()).hexdigest() == receipt['sha256'], 'Binary changed since the checked build')
    architectures = subprocess.check_output(['xcrun', 'lipo', '-archs', str(app / 'Contents/MacOS/QuickDraw')], text=True).split()
    require(set(architectures) == {'arm64', 'x86_64'}, 'Universal architectures missing')
    output = ROOT / '.build/releases'
    output.mkdir(exist_ok=True)
    source = archive(output / 'QuickDraw-0.1.0-source.zip', ROOT, 'QuickDraw', SOURCE_FILES)
    binary = archive(output / 'QuickDraw-0.1.0-macOS-universal-preview.zip', app, 'Quick Draw.app', APP_FILES)
    (output / 'manifest.json').write_text(json.dumps({'version': '0.1.0', 'source': source, 'app': binary,
        'signature': 'ad-hoc', 'notarized': False, 'published': False}, indent=2) + '\n')
    print('PASS: allowlisted source and universal preview archives prepared; nothing published')

if __name__ == '__main__':
    main()
