# Quick Draw

A small wheel for the apps and websites you use every day.

Click the floating button, choose a tool, and get back to what you were doing. Drag the button to move it. Find Quick Draw in the menu bar whenever you hide it.

## Set up your wheel

1. Open Quick Draw. The tool list starts empty.
2. Choose **Add Application** and pick an installed Mac app, or choose **Add Website** and enter its name and complete address.
3. Add up to eight tools. Use the arrows to change their order, or the options menu to rename or remove one.
4. Choose **Show wheel**, then click a tool to open it.

Quick Draw opens the original app. It does not copy its documents or include the app itself. Websites open in your default browser. Choose only apps and websites you trust.

The menu-bar icon offers **Show Quick Draw**, **Manage Tools**, **Hide Quick Draw**, and **Quit**. Quick Draw stays out of the Dock. Click the center button or press Escape while the wheel has focus to minimize it.

## Build this preview

Requires macOS 14 or later, Python 3, and Apple's Swift compiler (Xcode or Command Line Tools). There are no third-party runtime packages or package downloads.

```sh
python3 build.py
python3 verify.py
```

The app is created at `.build/Quick Draw.app`. The build does not install or launch it. You can copy a locally built app to Applications and open it normally.

This preview uses a local ad-hoc signature. It is not notarized by Apple. A downloaded prebuilt preview may be blocked by macOS security checks. Do not disable those checks. A Developer ID signed and notarized installer is still needed before recommending prebuilt downloads to general users.

Both Apple Silicon and Intel code are included. Automated execution is checked on the build machine; execution on another Mac and real pointer behavior on every display setup have not been verified.

## What stays on your Mac

Tools are saved in `~/Library/Application Support/Quick Draw/tools.json`. Button position is stored in this app's own preferences. Neither is bundled into a release or uploaded by Quick Draw.

No account, analytics, automatic sync, microphone, screen capture, clipboard history, Accessibility permission, background server, automatic update, or automatic login item is included. Opening a website or another app can cause that chosen tool to use its own network services.

Missing or changed app? Remove the old entry, or use **Choose application again** in its options menu. If settings cannot be read, Quick Draw preserves the original file. An explicit recovery action keeps a backup before starting an empty list.

## Prepare release files

```sh
python3 scripts/release.py
```

This produces a source archive and a universal Mac preview archive in `.build/releases/`, using explicit file lists. It never copies Git history, local settings, arbitrary neighboring files, or extended attributes. Nothing is published automatically.

See [PRIVACY.md](PRIVACY.md), [SECURITY.md](SECURITY.md), and [CONTRIBUTING.md](CONTRIBUTING.md). Code and original icon artwork are available under the [MIT license](LICENSE).
