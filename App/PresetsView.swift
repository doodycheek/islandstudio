import SwiftUI

/// The preset gallery: browse by category, save your own, share codes.
struct PresetsView: View {
    @EnvironmentObject var manager: IslandManager
    @State private var filter = "All"
    @State private var showSave = false
    @State private var newName = ""
    @State private var showRename = false
    @State private var renameID = ""
    @State private var renameText = ""

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var filters: [String] {
        ["All"] + PresetStore.categories + (manager.savedPresets.isEmpty ? [] : ["Mine"])
    }

    private var visible: [SavedPreset] {
        let all = PresetStore.builtIns + manager.savedPresets
        if filter == "All" { return all }
        return all.filter { PresetStore.category(for: $0.id) == filter }
    }

    private func isMine(_ preset: SavedPreset) -> Bool {
        manager.savedPresets.contains { $0.id == preset.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card(title: "Your presets", icon: "star.square.fill", tint: .orange,
                         footer: "Press and hold one of your own presets to copy its share code, rename it, or delete it. Anyone with Island Studio can paste a code to get your exact style.") {
                        HStack(spacing: 10) {
                            Button {
                                newName = ""
                                showSave = true
                            } label: {
                                Label("Save current", systemImage: "square.and.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.tertiarySystemFill)))
                            }
                            Button {
                                manager.importPresetFromClipboard()
                            } label: {
                                Label("Paste code", systemImage: "doc.on.clipboard")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.tertiarySystemFill)))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { name in
                                FilterChip(title: name, selected: filter == name) {
                                    filter = name
                                }
                            }
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visible) { preset in
                            PresetCard(preset: preset,
                                       category: PresetStore.category(for: preset.id),
                                       isCurrent: preset.id == manager.settings.currentPresetID,
                                       state: manager.previewState(style: preset.style, at: Date())) {
                                manager.apply(preset)
                            }
                            .contextMenu {
                                if isMine(preset) {
                                    Button {
                                        manager.copyShareCode(preset)
                                    } label: {
                                        Label("Copy share code", systemImage: "doc.on.doc")
                                    }
                                    Button {
                                        renameID = preset.id
                                        renameText = preset.name
                                        showRename = true
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        manager.deletePreset(id: preset.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } else {
                                    Button {
                                        manager.copyShareCode(preset)
                                    } label: {
                                        Label("Copy share code", systemImage: "doc.on.doc")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(ThemeBackground())
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .pinnedPreview()
            .alert("Save preset", isPresented: $showSave) {
                TextField("Name", text: $newName)
                Button("Save") { manager.saveCurrentAsPreset(named: newName) }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Rename preset", isPresented: $showRename) {
                TextField("Name", text: $renameText)
                Button("Save") { manager.renamePreset(id: renameID, to: renameText) }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
