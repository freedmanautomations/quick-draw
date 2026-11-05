import AppKit
import SwiftUI

@MainActor enum InterfaceChecks {
    private static func hasDrawnContent(_ bitmap: NSBitmapImageRep) -> Bool {
        var colors = Set<String>()
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 13) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 13) {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0.1 {
                    colors.insert("\(Int(color.redComponent * 31)),\(Int(color.greenComponent * 31)),\(Int(color.blueComponent * 31))")
                }
            }
        }
        return colors.count > 8
    }
    static func run(output: URL) throws {
        guard !FileManager.default.fileExists(atPath: output.path) else { throw LauncherError.invalid }
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("quickdraw-interface-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LauncherModel(store: ToolStore(directory: root))
        let empty = NSHostingView(rootView: ManageView(model: model))
        empty.frame = NSRect(x: 0, y: 0, width: 700, height: 600)
        empty.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        guard empty.fittingSize.width >= 650, model.document.tools.isEmpty else { throw LauncherError.invalid }
        let settingsOutput = output.deletingPathExtension().appendingPathExtension("settings.png")
        guard !FileManager.default.fileExists(atPath: settingsOutput.path) else { throw LauncherError.invalid }
        let settingsRenderer = ImageRenderer(content: ManageView(model: model).frame(width: 700, height: 600).environment(\.colorScheme, .light).background(Color.white))
        settingsRenderer.proposedSize = ProposedViewSize(width: 700, height: 600)
        settingsRenderer.scale = 2
        guard let settingsImage = settingsRenderer.nsImage, let settingsTIFF = settingsImage.tiffRepresentation,
              let emptyBitmap = NSBitmapImageRep(data: settingsTIFF), hasDrawnContent(emptyBitmap) else { throw LauncherError.invalid }
        guard let settingsPNG = emptyBitmap.representation(using: .png, properties: [:]), settingsPNG.count > 1000 else { throw LauncherError.invalid }
        try settingsPNG.write(to: settingsOutput, options: .withoutOverwriting)
        let names = ["Writing", "Planning", "Music", "Reading", "Calendar", "Projects"]
        for name in names { model.add(Tool(id: UUID(), name: name, kind: .website, target: "https://example.com/", bundleID: nil)) }
        model.expanded = true
        var launched = 0
        model.openWebsite = { _ in launched += 1; return true }
        let wheel = NSHostingView(rootView: WheelView(model: model))
        wheel.frame = NSRect(x: 0, y: 0, width: 420, height: 450)
        wheel.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        guard let bitmap = wheel.bitmapImageRepForCachingDisplay(in: wheel.bounds) else { throw LauncherError.invalid }
        wheel.cacheDisplay(in: wheel.bounds, to: bitmap)
        guard hasDrawnContent(bitmap) else { throw LauncherError.invalid }
        guard let data = bitmap.representation(using: .png, properties: [:]), data.count > 1000 else { throw LauncherError.invalid }
        try data.write(to: output, options: .withoutOverwriting)
        guard empty.window == nil, wheel.window == nil, launched == 0 else { throw LauncherError.invalid }
        print("PASS: hidden native settings and wheel render; synthetic labels; no visible window, title, screenshot, app launch or network access")
    }
}
