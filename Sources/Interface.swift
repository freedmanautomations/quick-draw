import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class LauncherModel: ObservableObject {
    @Published var document = ToolDocument()
    @Published var error: String?
    @Published var unreadable = false
    @Published var canRecover = false
    @Published var expanded = false
    let store: ToolStore
    var manage: () -> Void = {}
    var resize: () -> Void = {}
    var move: (CGSize, Bool) -> Void = { _, _ in }
    var openApplication: (URL, @escaping (Bool) -> Void) -> Void = { url, reply in
        let options = NSWorkspace.OpenConfiguration()
        options.activates = true
        options.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: url, configuration: options) { app, error in
            Task { @MainActor in reply(error == nil && app != nil) }
        }
    }
    var openWebsite: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    init(store: ToolStore) { self.store = store; reload() }
    func reload() {
        do { document = try store.load(); unreadable = false; canRecover = false; error = nil }
        catch { unreadable = true; canRecover = store.canRecover; self.error = LauncherError.storage.localizedDescription }
    }
    @discardableResult func update(_ mutate: (inout ToolDocument) throws -> Void) -> Bool {
        guard !unreadable else { return false }
        do {
            var next = document
            try mutate(&next)
            try store.save(next)
            document = next
            error = nil
            resize()
            return true
        } catch { self.error = (error as? LauncherError)?.localizedDescription ?? LauncherError.storage.localizedDescription; return false }
    }
    @discardableResult func add(_ tool: Tool) -> Bool {
        update { value in
            guard value.tools.count < 8 else { throw LauncherError.limit }
            value.tools.append(tool)
        }
    }
    func chooseApplication(replacing id: UUID? = nil) {
        guard id != nil || document.tools.count < 8 else { error = LauncherError.limit.localizedDescription; return }
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.applicationBundle]
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = false
        picker.treatsFilePackagesAsDirectories = false
        picker.prompt = "Add to wheel"
        if picker.runModal() == .OK, let selected = picker.url {
            do {
                var selectedTool = try Tool.application(at: selected)
                if let id {
                    selectedTool.id = id
                    let replacement = selectedTool
                    update { value in
                        guard let index = value.tools.firstIndex(where: { $0.id == id }) else { throw LauncherError.invalid }
                        value.tools[index] = replacement
                    }
                } else { add(selectedTool) }
            }
            catch { self.error = LauncherError.invalid.localizedDescription }
        }
    }
    func reorder(_ id: UUID, offset: Int) {
        update { value in
            guard let index = value.tools.firstIndex(where: { $0.id == id }), value.tools.indices.contains(index + offset) else { return }
            value.tools.swapAt(index, index + offset)
        }
    }
    func remove(_ id: UUID) { update { $0.tools.removeAll { $0.id == id } } }
    @discardableResult func rename(_ id: UUID, to name: String) -> Bool {
        update { value in
            guard let index = value.tools.firstIndex(where: { $0.id == id }) else { throw LauncherError.invalid }
            value.tools[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    func launch(_ id: UUID) {
        guard !unreadable, let tool = document.tools.first(where: { $0.id == id }) else { return }
        do {
            try tool.validate()
            switch tool.kind {
            case .application:
                let url = try tool.applicationURL()
                openApplication(url) { [weak self] success in self?.launched(success) }
            case .website:
                launched(openWebsite(try Tool.websiteURL(tool.target)))
            }
        } catch { self.error = (error as? LauncherError)?.localizedDescription ?? LauncherError.unavailable.localizedDescription }
    }
    private func launched(_ success: Bool) {
        if success { error = nil; expanded = false; resize() }
        else { error = "That tool could not open. Check it in Manage Tools." }
    }
    func recover() {
        do { try store.recover(); reload() }
        catch { self.error = LauncherError.storage.localizedDescription }
    }
}

struct BrandMark: View {
    var body: some View {
        Image(systemName: "square.grid.2x2.fill").font(.system(size: 24, weight: .medium))
            .foregroundStyle(Color(red: 0.32, green: 0.94, blue: 0.72))
    }
}
struct OrbView: View {
    @ObservedObject var model: LauncherModel
    @State private var gesture = OrbGesture()
    var body: some View {
        BrandMark().frame(width: 58, height: 58)
            .background(Color(red: 0.06, green: 0.12, blue: 0.13), in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                gesture.move(x: value.translation.width, y: value.translation.height)
                if gesture.dragged { model.move(value.translation, false) }
            }.onEnded { value in
                let click = gesture.finish()
                if click { model.expanded.toggle(); model.resize() }
                else { model.move(value.translation, true) }
            })
            .accessibilityLabel(model.expanded ? "Minimize Quick Draw" : "Open Quick Draw")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.expanded.toggle(); model.resize() }
            .help("Click to open. Drag to move. Restore from the menu bar.")
    }
}
struct WheelView: View {
    @ObservedObject var model: LauncherModel
    var body: some View {
        ZStack {
            if model.expanded {
                RoundedRectangle(cornerRadius: 28).fill(Color(red: 0.045, green: 0.08, blue: 0.09))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
                VStack {
                    HStack {
                        Text("Quick Draw").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Button("Manage Tools") { model.manage() }.buttonStyle(.plain).foregroundStyle(.mint)
                    }.padding(22)
                    Spacer()
                    if let error = model.error { Text(error).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center).padding(.horizontal, 24) }
                    Text("Your tools, one click away").font(.caption).foregroundStyle(.white.opacity(0.48)).padding(.bottom, 18)
                }
                if model.document.tools.isEmpty {
                    VStack(spacing: 12) {
                        Text("Make this wheel yours").font(.title3.weight(.semibold))
                        Text("Add apps and websites you reach for often.").font(.callout).foregroundStyle(.white.opacity(0.65))
                        Button("Add your first tool") { model.manage() }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                    }.offset(y: -40)
                    OrbView(model: model).offset(y: 80)
                } else {
                    ForEach(Array(model.document.tools.enumerated()), id: \.element.id) { index, tool in
                        let angle = Double(index) / Double(model.document.tools.count) * 2 * Double.pi - Double.pi / 2
                        Button { model.launch(tool.id) } label: {
                            VStack(spacing: 7) {
                                Image(systemName: tool.symbol).font(.system(size: 21)).frame(width: 48, height: 48)
                                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                Text(tool.name).font(.system(size: 11, weight: .medium)).lineLimit(2).frame(width: 80, height: 28)
                            }.frame(width: 82, height: 88).contentShape(Rectangle())
                        }.buttonStyle(.plain).help(tool.name).accessibilityLabel("Open " + tool.name)
                            .offset(x: cos(angle) * 132, y: sin(angle) * 132 + 10)
                    }
                    OrbView(model: model).offset(y: 10)
                }
            } else { OrbView(model: model) }
        }.foregroundStyle(.white)
            .frame(width: model.expanded ? 420 : 72, height: model.expanded ? 450 : 72)
            .preferredColorScheme(.dark)
    }
}

private struct ToolEditor: View {
    var existing: Tool?
    var save: (String, String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(existing == nil ? "Add a website" : "Rename tool").font(.title2.weight(.semibold))
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            if existing == nil {
                TextField("https://example.com", text: $address).textFieldStyle(.roundedBorder)
                Text("Use a complete http or https address. It opens in your default browser.").font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red).font(.caption) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(existing == nil ? "Add website" : "Save name") {
                    do { try save(name.trimmingCharacters(in: .whitespacesAndNewlines), address); dismiss() }
                    catch { self.error = (error as? LauncherError)?.localizedDescription ?? LauncherError.invalid.localizedDescription }
                }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(28).frame(width: 400)
            .onAppear { name = existing?.name ?? "" }
    }
}
struct ManageView: View {
    @ObservedObject var model: LauncherModel
    @State private var addWebsite = false
    @State private var rename: Tool?
    @State private var confirmRecovery = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Your wheel").font(.system(size: 28, weight: .semibold))
                    Text("Keep your everyday apps and websites within reach.").foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(model.document.tools.count) / 8").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }.padding(28)
            HStack(spacing: 12) {
                Button { model.chooseApplication() } label: { Label("Add Application", systemImage: "plus.app") }
                Button { addWebsite = true } label: { Label("Add Website", systemImage: "globe") }
                Spacer()
            }.padding(.horizontal, 28).padding(.bottom, 20).disabled(model.unreadable || model.document.tools.count >= 8)
            if let error = model.error {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).foregroundStyle(.orange)
                    if model.unreadable && model.canRecover {
                        Button("Keep a backup and start a new list") { confirmRecovery = true }
                    } else if model.unreadable {
                        Text("Check access to Quick Draw's settings folder, then reload. Your original file has not been replaced.").foregroundStyle(.secondary)
                    }
                    Button("Reload saved tools") { model.reload() }
                }.font(.callout).padding(.horizontal, 28).padding(.bottom, 16)
            }
            Divider()
            if model.document.tools.isEmpty && !model.unreadable {
                VStack(spacing: 12) {
                    Image(systemName: "cursorarrow.rays").font(.system(size: 35)).foregroundStyle(.secondary)
                    Text("Start with the tools you already use").font(.headline)
                    Text("Choose an installed app or add a website.\nQuick Draw opens it for you, without copying its data.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(model.document.tools.enumerated()), id: \.element.id) { index, tool in
                        HStack(spacing: 12) {
                            Image(systemName: tool.symbol).font(.title2).frame(width: 32).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tool.name).font(.headline).lineLimit(1)
                                Text(tool.kind == .application ? "Application" : "Website").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { model.reorder(tool.id, offset: -1) } label: { Image(systemName: "arrow.up") }.disabled(index == 0).help("Move up").accessibilityLabel("Move " + tool.name + " up")
                            Button { model.reorder(tool.id, offset: 1) } label: { Image(systemName: "arrow.down") }.disabled(index == model.document.tools.count - 1).help("Move down").accessibilityLabel("Move " + tool.name + " down")
                            Menu {
                                Button("Rename") { rename = tool }
                                if tool.kind == .application { Button("Choose application again") { model.chooseApplication(replacing: tool.id) } }
                                Button("Remove from wheel", role: .destructive) { model.remove(tool.id) }
                            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 28).accessibilityLabel("Options for " + tool.name)
                        }.padding(.vertical, 9)
                    }
                }.listStyle(.inset).disabled(model.unreadable)
            }
            Divider()
            HStack {
                Image(systemName: "lock.shield")
                Text("Stored on this Mac. No account, analytics or automatic sync.")
                Spacer()
                Button("Show wheel") { model.expanded = true; model.resize() }
            }.font(.caption).foregroundStyle(.secondary).padding(22)
        }.frame(minWidth: 650, idealWidth: 700, minHeight: 520, idealHeight: 600)
            .sheet(isPresented: $addWebsite) {
                ToolEditor { name, address in
                    let tool = Tool(id: UUID(), name: name, kind: .website, target: address, bundleID: nil)
                    try tool.validate(); if !model.add(tool) { throw LauncherError.storage }
                }
            }
            .sheet(item: $rename) { tool in
                ToolEditor(existing: tool) { name, _ in
                    var updated = tool; updated.name = name; try updated.validate(); if !model.rename(tool.id, to: name) { throw LauncherError.storage }
                }
            }
            .alert("Start a new list?", isPresented: $confirmRecovery) {
                Button("Cancel", role: .cancel) {}
                Button("Keep backup and start fresh") { model.recover() }
            } message: { Text("The unreadable file will be kept as a backup in Quick Draw's settings folder. Nothing will be launched.") }
    }
}
