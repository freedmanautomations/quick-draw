#!/usr/bin/env python3
from pathlib import Path
import plistlib, subprocess

ROOT = Path(__file__).resolve().parent
app = ROOT / '.build/Quick Draw.app'
executable = app / 'Contents/MacOS/QuickDraw'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
subprocess.run([str(ROOT / '.build/QuickDrawChecks'), '--self-test'], check=True)
architectures = subprocess.check_output(['xcrun', 'lipo', '-archs', str(executable)], text=True).split()
if set(architectures) != {'arm64', 'x86_64'}:
    raise RuntimeError('Universal architectures missing')
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
if info['CFBundleIdentifier'] != 'org.quickdraw.launcher' or info['LSUIElement'] is not True:
    raise RuntimeError('Unexpected app identity')
print('PASS: universal app, signature, identity and synthetic core checks')
