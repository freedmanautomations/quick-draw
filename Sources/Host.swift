import AppKit
import SwiftUI

final class WheelPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: LauncherModel!
    private var panel: WheelPanel!
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private var preferences: UserDefaults!
    private var anchor = NSPoint.zero
    private var dragStart: NSPoint?
    private var keyMonitor: Any?
    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences = UserDefaults(suiteName: Identity.bundleID)!
        model = LauncherModel(store: .standard())
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        if preferences.object(forKey: "anchorX") != nil && preferences.object(forKey: "anchorY") != nil {
            let x = preferences.double(forKey: "anchorX"), y = preferences.double(forKey: "anchorY")
            anchor = x.isFinite && y.isFinite ? NSPoint(x: x, y: y) : NSPoint(x: frame.maxX - 60, y: frame.midY)
        } else { anchor = NSPoint(x: frame.maxX - 60, y: frame.midY) }
        panel = WheelPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: WheelView(model: model))
        model.manage = { [weak self] in self?.manageTools() }
        model.resize = { [weak self] in self?.fit() }
        model.move = { [weak self] translation, ended in self?.move(translation, ended: ended) }
        installMenu()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, self?.panel.isKeyWindow == true {
                self?.model.expanded = false; self?.fit(); return nil
            }
            return event
        }
        fit()
        if model.document.tools.isEmpty { manageTools() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWheel(); return false
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }
    private func installMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Quick Draw")
        statusItem.button?.toolTip = "Quick Draw"
        let menu = NSMenu()
        for (title, action, key) in [("Show Quick Draw", #selector(showWheel), ""), ("Manage Tools...", #selector(manageTools), ","), ("Hide Quick Draw", #selector(hideWheel), "")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Quick Draw", action: #selector(quit), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        statusItem.menu = menu
    }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func showWheel() { model.expanded = true; fit() }
    @objc private func hideWheel() { model.expanded = false; panel.orderOut(nil) }
    @objc private func manageTools() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Quick Draw"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ManageView(model: model))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    private func screen() -> NSRect {
        let candidates = NSScreen.screens
        return (candidates.first { $0.visibleFrame.contains(anchor) } ?? NSScreen.main ?? candidates.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
    }
    private func fit() {
        let screen = screen()
        let width = model.expanded ? 420.0 : 72.0, height = model.expanded ? 450.0 : 72.0
        let offset = model.expanded ? (model.document.tools.isEmpty ? 80.0 : 10.0) : 0
        let proposed = PanelBounds(x: anchor.x - width / 2, y: anchor.y - height / 2 + offset, width: width, height: height)
        let result = proposed.clamped(to: PanelBounds(x: screen.minX, y: screen.minY, width: screen.width, height: screen.height))
        panel.setFrame(NSRect(x: result.x, y: result.y, width: result.width, height: result.height), display: true)
        panel.contentView?.setFrameSize(panel.frame.size)
        if model.expanded { panel.makeKeyAndOrderFront(nil) } else { panel.resignKey(); panel.orderFrontRegardless() }
    }
    private func move(_ value: CGSize, ended: Bool) {
        if dragStart == nil { dragStart = anchor }
        guard let start = dragStart else { return }
        anchor = NSPoint(x: start.x + value.width, y: start.y - value.height)
        let bounds = screen()
        anchor.x = max(bounds.minX + 36, min(anchor.x, bounds.maxX - 36))
        anchor.y = max(bounds.minY + 36, min(anchor.y, bounds.maxY - 36))
        fit()
        if ended {
            preferences.set(anchor.x, forKey: "anchorX"); preferences.set(anchor.y, forKey: "anchorY")
            dragStart = nil
        }
    }
}
