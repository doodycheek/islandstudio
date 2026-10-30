import SwiftUI

/// The preset gallery: browse, favorite, set a default, save your own, share codes.
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
        var list = ["All"]
        if !manager.settings.favoriteIDs.isEmpty { list.append("Favorites") }
        if !manager.savedPresets.isEmpty { list.append("Mine") }
        return list + PresetStore.categories
    }

    private var visible: [SavedPreset] {
        let all = manager.allPresets
        switch filter {
        case "All": return all
        case "Favorites": return all.filter { manager.isFavorite($0.id) }
        case "Mine": return manager.savedPresets
        default: return all.filter { PresetStore.category(for: $0.id) == filter }
        }
    }

    private func isMine(_ preset: SavedPreset) -> Bool {
        manager.savedPresets.contains { $0.id == preset.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card(title: "Your presets", icon: "star.square.fill", tint: .orange,
                         footer: "Press and hold any preset to set it as your default, favorite it, duplicate it or share it. Your default is what Back to default applies, and where the island returns after a holiday preset.") {
                        HStack(spacing: 10) {
                            WideButton(title: "Save current", icon: "square.and.arrow.down") {
                                newName = ""
                                showSave = true
                            }
                            WideButton(title: "Paste code", icon: "doc.on.clipboard") {
                                manager.importPresetFromClipboard()
                            }
                        }
                        HStack(spacing: 10) {
                            WideButton(title: "Surprise me", icon: "shuffle") {
                                manager.surprise()
                            }
                            WideButton(title: "Back to default", icon: "house.fill") {
                                manager.applyDefault()
                            }
                        }
                        if manager.hasUnsavedChanges, let current = manager.currentPreset {
                            WideButton(title: "Save changes to \(current.name)", icon: "arrow.triangle.2.circlepath") {
                                manager.updatePreset(id: current.id)
                            }
                        }
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

                    if visible.isEmpty {
                        Text("Nothing here yet.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 24)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visible) { preset in
                            PresetCard(preset: preset,
                                       category: PresetStore.category(for: preset.id),
                                       isCurrent: preset.id == manager.settings.currentPresetID,
                                       state: manager.previewState(style: preset.style, at: Date()),
                                       isDefault: preset.id == manager.settings.defaultPresetID,
                                       isFavorite: manager.isFavorite(preset.id)) {
                                manager.apply(preset)
                            }
                            .contextMenu {
                                Button {
                                    manager.setDefault(preset)
                                } label: {
                                    Label("Set as default", systemImage: "house")
                                }
                                Button {
                                    manager.toggleFavorite(preset.id)
                                } label: {
                                    Label(manager.isFavorite(preset.id) ? "Remove from favorites" : "Add to favorites",
                                          systemImage: manager.isFavorite(preset.id) ? "star.slash" : "star")
                                }
                                Button {
                                    manager.duplicatePreset(preset)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                Button {
                                    manager.copyShareCode(preset)
                                } label: {
                                    Label("Copy share code", systemImage: "doc.on.doc")
                                }
                                if isMine(preset) {
                                    Button {
                                        manager.updatePreset(id: preset.id)
                                    } label: {
                                        Label("Replace with current style", systemImage: "arrow.triangle.2.circlepath")
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
