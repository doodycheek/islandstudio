import PhotosUI
import SwiftUI

/// Root: three tabs, with the chosen theme and accent applied everywhere.
struct ContentView: View {
    @AppStorage("themeMode") private var themeMode = ThemeMode.system.rawValue
    @AppStorage("accentChoice") private var accentChoice = AccentChoice.purple.rawValue
    @AppStorage("selectedTab") private var selectedTab = AppTab.studio.rawValue

    private var accent: Color { (AccentChoice(rawValue: accentChoice) ?? .purple).color }

    var body: some View {
        TabView(selection: $selectedTab) {
            StudioView()
                .tabItem { Label("Studio", systemImage: "wand.and.stars") }
                .tag(AppTab.studio.rawValue)
            PresetsView()
                .tabItem { Label("Presets", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.presets.rawValue)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings.rawValue)
        }
        .tint(accent)
        .environment(\.themeAccent, accent)
        .preferredColorScheme((ThemeMode(rawValue: themeMode) ?? .system).colorScheme)
    }
}

// MARK: - Studio

/// The editor. Its settings follow the preview tab: Island, Expanded, or Lock Screen.
struct StudioView: View {
    @AppStorage("previewMode") private var previewMode = PreviewMode.island.rawValue

    private var mode: PreviewMode { PreviewMode(rawValue: previewMode) ?? .island }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    switch mode {
                    case .island: IslandSettings()
                    case .expanded: ExpandedSettings()
                    case .lock: LockSettings()
                    }
                }
                .padding(16)
                .animation(.easeInOut(duration: 0.2), value: previewMode)
            }
            .background(ThemeBackground())
            .navigationTitle("Studio")
            .navigationBarTitleDisplayMode(.inline)
            .pinnedPreview()
        }
    }
}

// MARK: Island tab

struct IslandSettings: View {
    @EnvironmentObject var manager: IslandManager
    @AppStorage("selectedTab") private var selectedTab = AppTab.studio.rawValue
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        let snapshot = manager.previewState(at: Date())
        VStack(spacing: 16) {
            Card(title: "Presets", icon: "square.grid.2x2.fill", tint: .purple,
                 actionTitle: "See all", action: { selectedTab = AppTab.presets.rawValue }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(PresetStore.builtIns + manager.savedPresets) { preset in
                            PresetTile(preset: preset,
                                       isCurrent: preset.id == manager.settings.currentPresetID,
                                       state: manager.previewState(style: preset.style, at: Date())) {
                                manager.apply(preset)
                            }
                        }
                    }
                }
            }

            Card(title: "Layout", icon: "rectangle.split.3x1.fill", tint: .blue,
                 footer: "The minimal bubble shows when another app, like FaceTime, takes the main island.") {
                NavigationLink {
                    SlotEditor(title: "Left side", slot: $manager.config.left)
                } label: {
                    SlotNavLabel(title: "Left side", slot: manager.config.left, state: snapshot)
                }
                .buttonStyle(.plain)
                RowDivider()
                NavigationLink {
                    SlotEditor(title: "Right side", slot: $manager.config.right)
                } label: {
                    SlotNavLabel(title: "Right side", slot: manager.config.right, state: snapshot)
                }
                .buttonStyle(.plain)
                RowDivider()
                NavigationLink {
                    SlotEditor(title: "Minimal bubble", slot: $manager.config.minimal)
                } label: {
                    SlotNavLabel(title: "Minimal bubble", slot: manager.config.minimal, state: snapshot)
                }
                .buttonStyle(.plain)
            }

            Card(title: "Style", icon: "paintbrush.fill", tint: .pink,
                 footer: "iOS only draws the island's outline faintly, and only in Dark Mode. Neon glow makes the island's own icons and text glow, which you can actually see.") {
                HStack(spacing: 10) {
                    IconBadge(systemName: "textformat", color: .indigo)
                    Text("Font")
                    Spacer()
                    Picker("Font", selection: $manager.config.fontDesign) {
                        Text("Default").tag("default")
                        Text("Rounded").tag("rounded")
                        Text("Mono").tag("monospaced")
                        Text("Serif").tag("serif")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                RowDivider()
                ToggleRow(title: "Bold", icon: "bold", color: .gray, isOn: $manager.config.bold)
                RowDivider()
                ToggleRow(title: "Neon glow", icon: "sparkle", color: .pink, isOn: $manager.config.glow)
                RowDivider()
                ColorPicker(selection: hexBinding(\.keylineHex)) {
                    HStack(spacing: 10) {
                        IconBadge(systemName: "paintpalette.fill", color: .orange)
                        Text("Accent & outline")
                    }
                }
            }

            Card(title: "Animation", icon: "waveform.path.ecg", tint: .teal) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Step speed")
                        Spacer()
                        Text("\(manager.frameInterval, specifier: "%.1f")s").foregroundStyle(.secondary)
                    }
                    Slider(value: $manager.frameInterval, in: 0.5...5, step: 0.5)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Ring & bar loop")
                        Spacer()
                        Text("\(manager.cycleLength, specifier: "%.0f")s").foregroundStyle(.secondary)
                    }
                    Slider(value: $manager.cycleLength, in: 1...10, step: 1)
                }
                if manager.isRunning {
                    RowDivider()
                    ToggleRow(title: "Pause animations", icon: "pause.fill", color: .yellow, isOn: $manager.paused)
                }
            }

            Card(title: "My photo", icon: "photo.fill", tint: .green,
                 footer: "Set any slot to My photo to use it. It's shrunk to a tiny icon to fit iOS's 4 KB limit.") {
                HStack(spacing: 12) {
                    if let data = manager.config.imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(manager.config.imageData == nil ? "Choose a photo" : "Change photo",
                              systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    if manager.config.imageData != nil {
                        Button("Remove", role: .destructive) {
                            manager.config.imageData = nil
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            loadPhoto(item)
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let tiny = ImageCompressor.tinyJPEG(from: data, maxBytes: 1000) {
                manager.config.imageData = tiny
            } else {
                manager.status = "Couldn't shrink that photo enough. Try a simpler image."
            }
        }
    }

    private func hexBinding(_ keyPath: WritableKeyPath<IslandState, String>) -> Binding<Color> {
        Binding(get: { Color(hex: manager.config[keyPath: keyPath]) },
                set: { manager.config[keyPath: keyPath] = $0.hexString })
    }
}

// MARK: Expanded tab

struct ExpandedSettings: View {
    @EnvironmentObject var manager: IslandManager

    var body: some View {
        VStack(spacing: 16) {
            Card(title: "Text", icon: "textformat", tint: .blue,
                 footer: "Long-press the island to see the expanded view.") {
                TextField("Title", text: $manager.config.expandedTitle)
                    .cardField()
                TextField("Subtitle", text: $manager.config.expandedSubtitle)
                    .cardField()
            }

            Card(title: "Extras", icon: "square.stack.3d.up.fill", tint: .indigo) {
                ToggleRow(title: "Preset buttons", icon: "hand.tap.fill", color: .indigo,
                          isOn: $manager.settings.showIslandButtons)
                RowDivider()
                ToggleRow(title: "Info chips", icon: "square.grid.2x2.fill", color: .teal,
                          isOn: $manager.config.expandedChips)
                RowDivider()
                ToggleRow(title: "Accent bar", icon: "minus.rectangle.fill", color: .orange,
                          isOn: $manager.config.expandedBar)
            }

            Card(title: "Pop-outs", icon: "rectangle.expand.vertical", tint: .orange,
                 footer: "Pop-outs briefly expand the island on their own. After tapping Test, swipe home within 5 seconds.") {
                ToggleRow(title: "Charging pop-out", icon: "bolt.fill", color: .green,
                          isOn: $manager.settings.chargingMode)
                RowDivider()
                ToggleRow(title: "Hourly pop-out", icon: "clock.fill", color: .orange,
                          isOn: $manager.settings.hourlyPopOut)
                RowDivider()
                ToggleRow(title: "Play sound", icon: "speaker.wave.2.fill", color: .pink,
                          isOn: $manager.settings.chimeSound)
                RowDivider()
                Button {
                    Task { await manager.testPopOut() }
                } label: {
                    Label("Test pop-out", systemImage: "play.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }
}

// MARK: Lock Screen tab

struct LockSettings: View {
    @EnvironmentObject var manager: IslandManager

    var body: some View {
        VStack(spacing: 16) {
            Card(title: "Layout", icon: "rectangle.grid.1x2.fill", tint: .blue,
                 footer: "Compact is one slim row and skips chips and the accent bar.") {
                Picker("Layout", selection: $manager.config.lockLayout) {
                    ForEach(LockLayout.allCases) { layout in
                        Text(layout.label).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
            }

            Card(title: "Background", icon: "circle.lefthalf.filled", tint: .purple,
                 footer: "Tinted uses your accent color. Glass lets your wallpaper show through.") {
                Picker("Background", selection: $manager.config.lockStyle) {
                    ForEach(LockStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }

            Card(title: "Text", icon: "textformat", tint: .pink) {
                ToggleRow(title: "Own Lock Screen text", icon: "lock.fill", color: .pink,
                          isOn: $manager.config.lockOwnText)
                if manager.config.lockOwnText {
                    TextField("Lock Screen title", text: $manager.config.lockTitle)
                        .cardField()
                    TextField("Lock Screen subtitle", text: $manager.config.lockSubtitle)
                        .cardField()
                } else {
                    Text("Using the Expanded title and subtitle.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Card(title: "Extras", icon: "sparkles", tint: .teal,
                 footer: "Chips show battery and date, plus weather and steps once they're set up.") {
                ToggleRow(title: "Info chips", icon: "square.grid.2x2.fill", color: .teal,
                          isOn: $manager.config.lockChips)
                RowDivider()
                ToggleRow(title: "Animated accent bar", icon: "minus.rectangle.fill", color: .orange,
                          isOn: $manager.config.lockAccent)
                RowDivider()
                NavigationLink {
                    LiveInfoSettingsView()
                } label: {
                    NavRowLabel(title: "Set up weather & steps", icon: "cloud.sun.fill", color: .blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
