import Foundation
import AppKit
import Darwin

enum Identity {
    static let bundleID = "org.quickdraw.launcher"
    static let storageFolder = "Quick Draw"
    static let version = "0.1.0"
}

enum LauncherError: LocalizedError {
    case invalid, unavailable, storage, changed, limit
    var errorDescription: String? {
        switch self {
        case .invalid: return "That tool could not be added. Choose an application or enter a complete http or https website address."
        case .unavailable: return "This application is missing or has changed. Choose it again in Manage Tools."
        case .storage: return "Your tools could not be read or saved. The existing file has been kept."
        case .changed: return "Your tools changed outside this window. Reopen Manage Tools before saving."
        case .limit: return "Your wheel holds up to 8 tools. Remove one before adding another."
        }
    }
}

enum ToolKind: String, Codable { case application, website }
struct Tool: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var kind: ToolKind
    var target: String
    var bundleID: String?
    var symbol: String { kind == .application ? "app.fill" : "globe" }
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 60,
              name.rangeOfCharacter(from: .controlCharacters) == nil,
              target.utf8.count <= 2048, !target.isEmpty,
              target.rangeOfCharacter(from: .controlCharacters) == nil else { throw LauncherError.invalid }
        switch kind {
        case .application:
            guard target.hasPrefix("/"), target.hasSuffix(".app"),
                  !target.split(separator: "/").contains(".."), let bundleID,
                  bundleID.range(of: "^[A-Za-z0-9][A-Za-z0-9.-]{0,199}$", options: .regularExpression) != nil else { throw LauncherError.invalid }
        case .website:
            guard bundleID == nil else { throw LauncherError.invalid }
            _ = try Self.websiteURL(target)
        }
    }
    static func websiteURL(_ value: String) throws -> URL {
        guard value == value.trimmingCharacters(in: .whitespacesAndNewlines), value.utf8.count <= 2048,
              value.rangeOfCharacter(from: .controlCharacters) == nil,
              let parts = URLComponents(string: value), ["https", "http"].contains(parts.scheme?.lowercased() ?? ""),
              parts.user == nil, parts.password == nil, let host = parts.host, !host.isEmpty,
              host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              parts.port == nil || (1...65535).contains(parts.port!), let url = parts.url else { throw LauncherError.invalid }
        return url
    }
    private static func boundedInfo(at url: URL) throws -> Data {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard fd >= 0 else { throw LauncherError.invalid }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_size <= 1048576 else { throw LauncherError.invalid }
        let data = try handle.read(upToCount: 1048577) ?? Data()
        guard data.count <= 1048576 else { throw LauncherError.invalid }
        return data
    }
    static func application(at selected: URL) throws -> Tool {
        let url = selected.resolvingSymlinksInPath().standardizedFileURL
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        guard url.isFileURL, url.pathExtension == "app",
              let data = try? boundedInfo(at: infoURL),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              info["CFBundlePackageType"] as? String == "APPL",
              let identifier = info["CFBundleIdentifier"] as? String,
              let executable = info["CFBundleExecutable"] as? String, !executable.isEmpty,
              !executable.contains("/"), ![".", ".."].contains(executable),
              FileManager.default.isExecutableFile(atPath: url.appendingPathComponent("Contents/MacOS").appendingPathComponent(executable).path) else { throw LauncherError.invalid }
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let tool = Tool(id: UUID(), name: String(name.prefix(60)), kind: .application, target: url.path, bundleID: identifier)
        try tool.validate()
        return tool
    }
    func applicationURL() throws -> URL {
        try validate()
        guard kind == .application else { throw LauncherError.invalid }
        let url = URL(fileURLWithPath: target)
        guard let selected = try? Self.application(at: url), selected.bundleID == bundleID,
              selected.target == target else { throw LauncherError.unavailable }
        return url
    }
}

struct ToolDocument: Codable, Equatable {
    var version = 1
    var tools: [Tool] = []
    func validate() throws {
        guard version == 1, tools.count <= 8, Set(tools.map(\.id)).count == tools.count else { throw LauncherError.invalid }
        for tool in tools { try tool.validate() }
    }
    static func decode(_ data: Data) throws -> ToolDocument {
        guard data.count <= 65536, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["version", "tools"], let rows = object["tools"] as? [[String: Any]], rows.count <= 8 else { throw LauncherError.invalid }
        for row in rows {
            let allowed: Set<String> = row["bundleID"] == nil ? ["id", "name", "kind", "target"] : ["id", "name", "kind", "target", "bundleID"]
            guard Set(row.keys) == allowed else { throw LauncherError.invalid }
        }
        let document = try JSONDecoder().decode(ToolDocument.self, from: data)
        try document.validate()
        return document
    }
}

final class ToolStore {
    let directory: URL
    private var expected: Data?
    private var loaded = false
    init(directory: URL) { self.directory = directory }
    static func standard() -> ToolStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ToolStore(directory: support.appendingPathComponent(Identity.storageFolder, isDirectory: true))
    }
    private func descriptor(create: Bool) throws -> Int32 {
        if !FileManager.default.fileExists(atPath: directory.path) {
            guard create else { return -1 }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        let fd = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw LauncherError.storage }
        return fd
    }
    private func raw() throws -> Data? {
        let dir = try descriptor(create: false)
        if dir == -1 { return nil }
        defer { close(dir) }
        let fd = openat(dir, "tools.json", O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        if fd == -1 && errno == ENOENT { return nil }
        guard fd >= 0 else { throw LauncherError.storage }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_size <= 65536 else { throw LauncherError.storage }
        let data = try handle.read(upToCount: 65537) ?? Data()
        guard data.count <= 65536 else { throw LauncherError.storage }
        return data
    }
    var canRecover: Bool { !loaded && expected != nil }
    func load() throws -> ToolDocument {
        loaded = false
        expected = nil
        expected = try raw()
        let document = try expected.map(ToolDocument.decode) ?? ToolDocument()
        loaded = true
        return document
    }
    private func write(_ document: ToolDocument) throws {
        try document.validate()
        let data = try JSONEncoder().encode(document)
        guard data.count <= 65536 else { throw LauncherError.invalid }
        let dir = try descriptor(create: true)
        defer { close(dir) }
        guard fchmod(dir, 0o700) == 0 else { throw LauncherError.storage }
        let name = ".tools-" + UUID().uuidString
        let fd = openat(dir, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw LauncherError.storage }
        var success = false
        defer { close(fd); if !success { unlinkat(dir, name, 0) } }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                guard count > 0 else { throw LauncherError.storage }
                offset += count
            }
        }
        guard fsync(fd) == 0, renameat(dir, name, dir, "tools.json") == 0 else { throw LauncherError.storage }
        success = true
        expected = data
        loaded = true
    }
    private func locked<T>(_ action: () throws -> T) throws -> T {
        let dir = try descriptor(create: true)
        defer { close(dir) }
        guard fchmod(dir, 0o700) == 0 else { throw LauncherError.storage }
        let lock = openat(dir, ".tools.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
        guard lock >= 0 else { throw LauncherError.storage }
        defer { close(lock) }
        var info = stat()
        guard fstat(lock, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1,
              fchmod(lock, 0o600) == 0, flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw LauncherError.changed }
        defer { flock(lock, LOCK_UN) }
        return try action()
    }
    func save(_ document: ToolDocument) throws {
        guard loaded else { throw LauncherError.storage }
        try locked {
            guard try raw() == expected else { throw LauncherError.changed }
            try write(document)
        }
    }
    func recover() throws {
        try locked {
            guard !loaded, let expected, try raw() == expected else { throw LauncherError.changed }
            let dir = try descriptor(create: false)
            guard dir >= 0 else { throw LauncherError.storage }
            defer { close(dir) }
            let backup = "tools.unreadable-" + UUID().uuidString + ".json"
            let original = openat(dir, "tools.json", O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
            guard original >= 0 else { throw LauncherError.storage }
            let privateMode = fchmod(original, 0o600)
            close(original)
            guard privateMode == 0, renameat(dir, "tools.json", dir, backup) == 0 else { throw LauncherError.storage }
            do { try write(ToolDocument()) }
            catch { _ = renameat(dir, backup, dir, "tools.json"); throw error }
        }
    }
}

struct PanelBounds: Equatable {
    var x: Double, y: Double, width: Double, height: Double
    func clamped(to screen: PanelBounds) -> PanelBounds {
        let w = min(width, screen.width), h = min(height, screen.height)
        return PanelBounds(x: max(screen.x, min(x, screen.x + screen.width - w)), y: max(screen.y, min(y, screen.y + screen.height - h)), width: w, height: h)
    }
}
struct OrbGesture {
    private(set) var dragged = false
    mutating func move(x: Double, y: Double) { if hypot(x, y) >= 4 { dragged = true } }
    mutating func finish() -> Bool { let click = !dragged; dragged = false; return click }
}
