#!/usr/bin/env python3
"""Build only from this directory, using system frameworks and a local signature."""
from pathlib import Path
import json, plistlib, struct, subprocess, hashlib, uuid, importlib.util

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / '.build'
BUNDLE = BUILD / 'Quick Draw.app'
SOURCES = sorted((ROOT / 'Sources').glob('*.swift'))

def run(args):
    return subprocess.run(args, cwd=ROOT, check=True, capture_output=True, text=True)

def main():
    BUILD.mkdir(exist_ok=True)
    contents = BUNDLE / 'Contents'
    for name in ['MacOS', 'Resources']:
        (contents / name).mkdir(parents=True, exist_ok=True)
    outputs = []
    for architecture in ['arm64', 'x86_64']:
        binary = BUILD / ('QuickDraw-' + architecture)
        run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-O', '-gnone',
             '-target', architecture + '-apple-macos14.0', '-module-cache-path', str(BUILD / 'modules'),
             '-debug-prefix-map', str(ROOT) + '=/src/QuickDraw', '-file-prefix-map', str(ROOT) + '=/src/QuickDraw',
             '-o', str(binary)] + [str(path.relative_to(ROOT)) for path in SOURCES])
        outputs.append(binary)
    executable = contents / 'MacOS/QuickDraw'
    run(['xcrun', 'lipo', '-create'] + [str(p) for p in outputs] + ['-output', str(executable)])
    executable.chmod(0o755)
    info = {'CFBundleName': 'Quick Draw', 'CFBundleDisplayName': 'Quick Draw', 'CFBundleIdentifier': 'org.quickdraw.launcher',
            'CFBundleExecutable': 'QuickDraw', 'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': '0.1.0',
            'CFBundleVersion': '1', 'LSMinimumSystemVersion': '14.0', 'LSUIElement': True,
            'NSHighResolutionCapable': True, 'CFBundleIconFile': 'QuickDraw'}
    (contents / 'Info.plist').write_bytes(plistlib.dumps(info))
    icon_program = BUILD / 'make-icon'
    run(['xcrun', 'swiftc', '-module-cache-path', str(BUILD / 'modules'), 'scripts/icon.swift', '-o', str(icon_program)])
    original = BUILD / ('icon-source-' + uuid.uuid4().hex + '.png')
    run([str(icon_program), str(original)])
    tags = [('icp4', 16), ('icp5', 32), ('icp6', 64), ('ic07', 128), ('ic08', 256), ('ic09', 512), ('ic10', 1024)]
    chunks = []
    for tag, size in tags:
        output = BUILD / ('icon-' + str(size) + '.png')
        run(['sips', '-z', str(size), str(size), str(original), '--out', str(output)])
        data = output.read_bytes()
        chunks.append(tag.encode() + struct.pack('>I', len(data) + 8) + data)
    payload = b''.join(chunks)
    (contents / 'Resources/QuickDraw.icns').write_bytes(b'icns' + struct.pack('>I', len(payload) + 8) + payload)
    run(['codesign', '--force', '--sign', '-', '--identifier', 'org.quickdraw.launcher', str(BUNDLE)])
    run(['codesign', '--verify', '--deep', '--strict', str(BUNDLE)])
    architectures = run(['xcrun', 'lipo', '-archs', str(executable)]).stdout.strip().split()
    if set(architectures) != {'arm64', 'x86_64'}:
        raise RuntimeError('Universal architectures missing')
    checker = BUILD / 'QuickDrawChecks'
    checks = ['Sources/Core.swift', 'Sources/Interface.swift', 'Tests/SelfTest.swift', 'Tests/InterfaceChecks.swift', 'Tests/CheckMain.swift']
    run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-O', '-gnone',
         '-module-cache-path', str(BUILD / 'modules'), '-file-prefix-map', str(ROOT) + '=/src/QuickDraw',
         '-debug-prefix-map', str(ROOT) + '=/src/QuickDraw', '-o', str(checker)] + checks)
    result = run([str(checker), '--self-test'])
    (BUILD / 'checks.log').write_text(result.stdout)
    spec = importlib.util.spec_from_file_location('release_manifest', ROOT / 'scripts/release.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    source_hashes = {name: hashlib.sha256(module.checked(ROOT, name).read_bytes()).hexdigest() for name in module.SOURCE_FILES}
    receipt = {'sourceHashes': source_hashes, 'version': '0.1.0', 'architectures': architectures, 'minimumMacOS': '14.0', 'signature': 'ad-hoc',
               'notarized': False, 'installed': False, 'sha256': hashlib.sha256(executable.read_bytes()).hexdigest()}
    (BUILD / 'build.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('PASS: universal Mac candidate built and locally signed; standalone self-tests passed; no installation')

if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stdout or '')
        print(error.stderr or '')
        raise SystemExit(error.returncode)
