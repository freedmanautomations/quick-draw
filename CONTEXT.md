# Quick Draw source map

`Sources/` contains the standalone Mac launcher. `Tests/` contains isolated synthetic checks and detached-view rendering. Test code is compiled into a separate helper and is not bundled in the application.

`build.py` builds a universal, locally signed app and runs the checks. `verify.py` repeats the core and package checks. `scripts/icon.swift` draws the original generic icon; each build regenerates it. `scripts/release.py` exports only explicit source and app file lists, bound to the checked build receipt.

`.build/` contains local generated output and is excluded from source control. Runtime settings are outside this source tree. No other repository, server, account or model is needed to build or run the launcher.
