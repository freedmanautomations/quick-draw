import Foundation
import AppKit
import Darwin

@MainActor enum SelfTest {
    static func run() throws {
        var checks = 0
        func check(_ value: @autoclosure () throws -> Bool, _ label: String) throws {
            guard try value() else { throw LauncherError.invalid }
            checks += 1
            print("PASS: " + label)
        }
        func rejects(_ label: String, _ operation: () throws -> Void) throws {
            do { try operation() } catch { checks += 1; print("PASS: " + label); return }
            throw LauncherError.invalid
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("quickdraw-check-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ToolStore(directory: root.appendingPathComponent("settings"))
        try check(try store.load().tools.isEmpty, "first launch has zero tools")
        try check(!FileManager.default.fileExists(atPath: store.directory.path), "reading defaults creates no settings")
        let site = Tool(id: UUID(), name: "Example", kind: .website, target: "https://example.com/", bundleID: nil)
        try store.save(ToolDocument(tools: [site]))
        try check(try store.load().tools == [site], "tool persists without network access")
        let settings = store.directory.appendingPathComponent("tools.json")
        let fileMode = try FileManager.default.attributesOfItem(atPath: settings.path)[.posixPermissions] as? Int
        let dirMode = try FileManager.default.attributesOfItem(atPath: store.directory.path)[.posixPermissions] as? Int
        try check(fileMode == 0o600 && dirMode == 0o700, "private file and directory permissions")
        for value in ["javascript:alert(1)", "file:///tmp/example", "data:text/plain,hello", "ssh://example.com", "https://user:pass@example.com", "https://user@example.com", "https://", "https://example.com\n", " https://example.com", "https://example.com:0"] {
            try rejects("unsafe website refused") { _ = try Tool.websiteURL(value) }
        }
        try check(try Tool.websiteURL("http://localhost:8080/").host == "localhost", "explicit local website accepted")
        try rejects("unknown fields refused") { _ = try ToolDocument.decode(Data("{\"version\":1,\"tools\":[],\"command\":\"anything\"}".utf8)) }
        try rejects("truncated JSON refused") { _ = try ToolDocument.decode(Data("{\"version\":".utf8)) }
        try rejects("unknown schema refused") { try ToolDocument(version: 2).validate() }
        try rejects("duplicate identifiers refused") { try ToolDocument(tools: [site, site]).validate() }
        try rejects("more than eight tools refused") { try ToolDocument(tools: (0..<9).map { _ in Tool(id: UUID(), name: site.name, kind: site.kind, target: site.target, bundleID: nil) }).validate() }
        try rejects("blank label refused") { try Tool(id: UUID(), name: " ", kind: .website, target: site.target).validate() }
        try rejects("long label refused") { try Tool(id: UUID(), name: String(repeating: "a", count: 61), kind: .website, target: site.target).validate() }
        try rejects("website cannot carry app identity") { try Tool(id: UUID(), name: "Test", kind: .website, target: site.target, bundleID: "org.example.fixture").validate() }
        try rejects("script path cannot be app target") { try Tool(id: UUID(), name: "Test", kind: .application, target: "/bin/sh", bundleID: "org.example.fixture").validate() }
        try rejects("missing app refused") { _ = try Tool(id: UUID(), name: "Missing", kind: .application, target: root.appendingPathComponent("Missing.app").path, bundleID: "org.example.fixture").applicationURL() }
        let app = root.appendingPathComponent("Fixture.app")
        let mac = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: mac, withIntermediateDirectories: true)
        let executable = mac.appendingPathComponent("Fixture")
        try Data([0]).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let infoURL = app.appendingPathComponent("Contents/Info.plist")
        var info = ["CFBundlePackageType": "APPL", "CFBundleIdentifier": "org.example.fixture", "CFBundleExecutable": "Fixture", "CFBundleName": "Fixture"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
        let selected = try Tool.application(at: app)
        try check(try selected.applicationURL().path == app.resolvingSymlinksInPath().path, "selected app is identity bound")
        info["CFBundleIdentifier"] = "org.example.replaced"
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
        try rejects("changed app identity refused at launch") { _ = try selected.applicationURL() }
        let corrupt = root.appendingPathComponent("corrupt")
        try FileManager.default.createDirectory(at: corrupt, withIntermediateDirectories: true)
        let original = corrupt.appendingPathComponent("tools.json"), originalBytes = Data("invalid original".utf8)
        try originalBytes.write(to: original)
        let badStore = ToolStore(directory: corrupt)
        try rejects("corrupt startup refuses silent defaults") { _ = try badStore.load() }
        try rejects("corrupt original cannot be overwritten by save") { try badStore.save(ToolDocument()) }
        try check(try Data(contentsOf: original) == originalBytes, "corrupt original preserved byte for byte")
        try badStore.recover()
        let backups = try FileManager.default.contentsOfDirectory(at: corrupt, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("tools.unreadable-") }
        try check(backups.count == 1 && (try Data(contentsOf: backups[0])) == originalBytes, "explicit recovery archives exact original")
        try check(try badStore.load().tools.isEmpty, "explicit recovery creates empty list")
        let lockPath = store.directory.appendingPathComponent(".tools.lock")
        let held = open(lockPath.path, O_RDWR)
        guard held >= 0, flock(held, LOCK_EX | LOCK_NB) == 0 else { throw LauncherError.storage }
        try rejects("simultaneous writer lock refuses replacement") { try store.save(ToolDocument()) }
        _ = flock(held, LOCK_UN); close(held)
        try check(try store.load().tools == [site], "contended save preserves original content")
        let concurrent = ToolStore(directory: store.directory)
        _ = try concurrent.load()
        try store.save(ToolDocument())
        try rejects("stale writer refuses overwriting newer settings") { try concurrent.save(ToolDocument(tools: [site])) }
        try check(try store.load().tools.isEmpty, "conflicting save preserves current content")
        let outside = root.appendingPathComponent("outside.json")
        try originalBytes.write(to: outside)
        try FileManager.default.removeItem(at: settings)
        try FileManager.default.createSymbolicLink(at: settings, withDestinationURL: outside)
        try rejects("symlink settings refused") { _ = try store.load() }
        try check(try Data(contentsOf: outside) == originalBytes, "symlink target unchanged")
        let linkDir = root.appendingPathComponent("directory-link")
        try FileManager.default.createSymbolicLink(at: linkDir, withDestinationURL: corrupt)
        try rejects("symlink directory refused") { _ = try ToolStore(directory: linkDir).load() }
        let oversized = root.appendingPathComponent("large")
        try FileManager.default.createDirectory(at: oversized, withIntermediateDirectories: true)
        try Data(repeating: 65, count: 65537).write(to: oversized.appendingPathComponent("tools.json"))
        let hugeStore = ToolStore(directory: oversized)
        try rejects("oversized settings refused") { _ = try hugeStore.load() }
        try check(!hugeStore.canRecover, "unsafe recovery is not offered for unreadable data")
        var gesture = OrbGesture()
        try check(gesture.finish(), "click toggles once")
        gesture.move(x: 10, y: 0)
        try check(!gesture.finish(), "drag cannot launch or toggle")
        try check(gesture.finish(), "gesture state resets after drag")
        let screen = PanelBounds(x: -1600, y: -400, width: 1600, height: 900)
        try check(PanelBounds(x: -2000, y: -500, width: 420, height: 450).clamped(to: screen) == PanelBounds(x: -1600, y: -400, width: 420, height: 450), "negative monitor coordinates clamped")
        try check(PanelBounds(x: 5000, y: 5000, width: 420, height: 450).clamped(to: screen) == PanelBounds(x: -420, y: 50, width: 420, height: 450), "offscreen position restored")
        try check(Identity.bundleID == "org.quickdraw.launcher" && Identity.storageFolder == "Quick Draw", "standalone identity fixed and isolated")
        let model = LauncherModel(store: ToolStore(directory: root.appendingPathComponent("model")))
        var opened = 0
        model.openWebsite = { _ in opened += 1; return true }
        model.add(site)
        model.expanded = true
        model.launch(site.id)
        try check(opened == 1 && !model.expanded, "explicit launch happens once and collapses wheel")
        model.launch(UUID())
        try check(opened == 1, "unknown identifier cannot launch a target")
        model.rename(site.id, to: "Renamed")
        try check(model.document.tools.first?.name == "Renamed", "rename persists")
        let second = Tool(id: UUID(), name: "Second", kind: .website, target: "https://example.org/", bundleID: nil)
        model.add(second); model.reorder(second.id, offset: -1)
        try check(model.document.tools.first?.id == second.id, "reorder persists")
        model.remove(site.id)
        try check(model.document.tools.count == 1, "remove changes only selected tool")
        try check(opened == 1, "editing and recovery never launch tools")
        let blocker = ToolStore(directory: model.store.directory)
        _ = try blocker.load()
        try blocker.save(ToolDocument())
        try check(!model.rename(second.id, to: "Unsaved"), "failed edit reports failure without pretending to save")
        print("PASS: \(checks) standalone core checks; synthetic fixtures only")
    }
}
