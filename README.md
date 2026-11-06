# Quick Draw

A small wheel for the apps and websites you use every day.

Click the floating button, choose a tool, and get back to what you were doing. Drag the button to move it. Find Quick Draw in the menu bar whenever you hide it.

## Download

1. Download `Quick-Draw-0.1.0-mac.zip` from the [latest release](https://github.com/freedmanautomations/quick-draw/releases/latest). It needs macOS 14 or later and runs on Apple Silicon and Intel Macs.
2. Double-click the zip, then drag **Quick Draw** into your Applications folder.
3. Open Quick Draw. The first time, macOS says it could not verify that Quick Draw is free of malware. Close that message, open **System Settings > Privacy & Security**, scroll down, and click **Open Anyway** next to Quick Draw. Confirm once more. After that it opens normally.

That one-time step appears because this free preview is not registered with Apple. It only allows Quick Draw itself; every other macOS security check stays on. If you would rather not do it, build the app yourself from this source (see below). The release page lists a SHA-256 checksum so you can confirm your download matches the published file.

## Set up your wheel

1. Open Quick Draw. The tool list starts empty.
2. Choose **Add Application** and pick an installed Mac app, or choose **Add Website** and enter its name and complete address.
3. Add up to eight tools. Use the arrows to change their order, or the options menu to rename or remove one.
4. Choose **Show wheel**, then click a tool to open it.

Quick Draw opens the original app. It does not copy its documents or include the app itself. Websites open in your default browser. Choose only apps and websites you trust.

The menu-bar icon offers **Show Quick Draw**, **Manage Tools**, **Hide Quick Draw**, and **Quit**. Quick Draw stays out of the Dock. Click the center button or press Escape while the wheel has focus to minimize it.

## Make it yours

Quick Draw is not tied to any company or product. It opens whatever you put on it, so the wheel is only as good as the tools you choose. Find an app or website you like, add it, and swap it out when something better comes along.

- **Any Mac app.** Paid, free, or open source. If it sits in your Applications folder, it can go on the wheel. Notes, a password manager, a design tool, a code editor, a chat app.
- **Any website.** Email, calendar, a shared drive, a project board, a spreadsheet you open every morning, a free AI chat tool. Paste the full address, starting with `https://`.
- **A tool running on your own Mac.** Many open source tools run in your browser at a local address such as `http://localhost:8080`. Add that address as a website and it opens like anything else.
- **A specific page, not just a home page.** Point a slot straight at the board, folder, or report you check every day so it opens one click deeper.

Ways to get the most out of it:

- Keep it to the tools you reach for many times a day. Eight is the limit on purpose.
- Give each one a short name. Long labels are harder to read at a glance.
- Use the arrows to put your most used tools first.
- Change the lineup when your work changes. Removing a tool only removes the shortcut, never the app or its files.
- Drag the floating button to a corner where it stays out of the way.

Want to change how the wheel itself works? The source is open under the MIT license. Change it, build it with the steps below, and use your own version.

## Build it yourself

Requires macOS 14 or later, Python 3, and Apple's Swift compiler (Xcode or Command Line Tools). There are no third-party runtime packages or package downloads.

```sh
python3 build.py
python3 verify.py
```

The app is created at `.build/Quick Draw.app`. The build does not install or launch it. You can copy a locally built app to Applications and open it normally.

The downloadable app is built this same way and carries a local ad-hoc signature, not an Apple notarization, which is why the first open needs the one-time **Open Anyway** step above. Never turn off Gatekeeper or other macOS security settings to run it.

Both Apple Silicon and Intel code are included. Launch is checked on the build machine. Other Macs and real pointer behavior on every display setup have not been verified.

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
