# Contributing

Keep changes small and include a reproducible example. This project uses Swift, AppKit and SwiftUI with system frameworks only.

Run `python3 build.py` and `python3 verify.py`. Tests use temporary synthetic settings and do not launch selected tools or access personal data. A hidden interface render can be created with:

```sh
".build/QuickDrawChecks" --render-check /tmp/quick-draw-preview.png
```

The output file must not already exist. This renders only the app's own detached views with example labels; it does not capture the desktop.

Keep new dependencies, background services, permission requests, arbitrary command execution and network behavior out of changes unless their design and security implications are discussed first. New release files must be added deliberately to the allowlist in `scripts/release.py`. Never add runtime settings, credentials or local user data to source.
