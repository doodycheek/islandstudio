import PhotosUI
import SwiftUI

/// Root: three tabs, with the chosen theme and accent applied everywhere.
struct ContentView: View {
    @EnvironmentObject var manager: IslandManager
    @AppStorage("themeMode") private var themeMode = ThemeMode.system.rawValue
    @AppStorage("accentChoice") private var accentChoice = AccentChoice.purple.rawValue
    @AppStorage("selectedTab") private var selectedTab = AppTab.studio.rawValue

    private var accent: Color {
        let choice = AccentChoice(rawValue: accentChoice) ?? .purple
        return choice == .island ? manager.config.accentColor : choice.color
    }

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
        .sensoryFeedback(.selection, trigger: manager.settings.currentPresetID)
    }
}

// MARK: - Shared bindings

extension IslandManager {
    /// Two-way binding between a hex string in your style and a ColorPicker.
    func colorBinding(_ keyPath: WritableKeyPath<IslandState, String>) -> Binding<Color> {
        Binding(get: { Color(hex: self.config[keyPath: keyPath]) },
                set: { self.config[keyPath: keyPath] = $0.hexString })
    }

    /// On/off for optional colors stored as hex ("" means automatic).
    func customColorToggle(_ keyPath: WritableKeyPath<IslandState, String>) -> Binding<Bool> {
        Binding(get: { !self.config[keyPath: keyPath].isEmpty },
                set: { self.config[keyPath: keyPath] = $0 ? "FFFFFFFF" : "" })
    }
}

/// Chips for choosing what the progress bar shows.
struct BarStylePicker: View {
    @Binding var style: LockBar

    var body: some View {
        HStack(spacing: 8) {
            ForEach(LockBar.allCases) { option in
                FilterChip(title: option.label, selected: style == option) {
                    style = option
                }
            }
            Spacer(minLength: 0)
        }
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
                    case .lock, .aod: LockSettings()
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
    @State private var paletteItem: PhotosPickerItem?
    @State private var photoPalette: [String] = []
    @State private var showSave = false
    @State private var newName = ""

    private let weights = ["thin", "light", "regular", "medium", "semibold", "bold", "heavy", "black"]

    private var weightBinding: Binding<String> {
        Binding(get: {
            manager.config.fontWeight.isEmpty ? (manager.config.bold ? "bold" : "regular") : manager.config.fontWeight
        }, set: { manager.config.fontWeight = $0 })
    }

    private var followBinding: Binding<Bool> {
        Binding(get: { manager.slotsFollowAccent }, set: { manager.setSlotsFollowAccent($0) })
    }

    var body: some View {
        let snapshot = manager.previewState(at: Date())
        VStack(spacing: 16) {
            presetsCard
            statusCard
            bubbleCard
            colorsCard
            layoutCard(snapshot)
            textCard
            backgroundCard
            animationCard
            photoCard
        }
        .onChange(of: photoItem) { _, item in
            loadPhoto(item)
        }
        .onChange(of: paletteItem) { _, item in
            loadPalette(item)
        }
        .alert("Save as a new preset", isPresented: $showSave) {
            TextField("Name", text: $newName)
            Button("Save") { manager.saveCurrentAsPreset(named: newName) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var presetsCard: some View {
        Card(title: "Presets", icon: "square.grid.2x2.fill", tint: .purple,
             actionTitle: "See all", action: { selectedTab = AppTab.presets.rawValue }) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(manager.allPresets) { preset in
                        PresetTile(preset: preset,
                                   isCurrent: preset.id == manager.settings.currentPresetID,
                                   state: manager.previewState(style: preset.style, at: Date())) {
                            manager.apply(preset)
                        }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    PillButton(title: "Save as new", icon: "plus.square.on.square") {
                        newName = ""
                        showSave = true
                    }
                    if manager.hasUnsavedChanges, let current = manager.currentPreset {
                        PillButton(title: "Update \(current.name)", icon: "arrow.triangle.2.circlepath") {
                            manager.updatePreset(id: current.id)
                        }
                    }
                    PillButton(title: "Back to default", icon: "house.fill") {
                        manager.applyDefault()
                    }
                    PillButton(title: "Surprise me", icon: "shuffle") {
                        manager.surprise()
                    }
                }
            }
        }
    }

    private var bubbleCard: some View {
        Card(title: "Small bubble mode", icon: "circle.dashed", tint: .pink,
             footer: "Handy while a delivery or ride is on your island. Your island updates rarely so the other app takes the big spot and your minimal bubble shows. It turns itself off after the time you pick. In Shortcuts, the Set Small Bubble Mode action can turn it on for you when Uber Eats opens.") {
            BubbleControls()
        }
    }

    private var statusCard: some View {
        Card(title: "Quick status", icon: "bubble.left.fill", tint: .green,
             footer: manager.settings.activeStatus == nil
                ? "Tap one to put it on your island. It sits on top of your preset until you clear it, and it can clear itself."
                : "This is showing on your island right now. Clear it to go back to your preset.") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(manager.settings.statuses) { item in
                        FilterChip(title: item.emoji + " " + item.text,
                                   selected: manager.settings.activeStatus?.id == item.id) {
                            manager.setStatus(item)
                        }
                    }
                }
            }
            if manager.settings.activeStatus != nil {
                WideButton(title: "Clear status", icon: "xmark.circle") {
                    manager.setStatus(nil)
                }
            }
            NavigationLink {
                StatusSettingsView()
            } label: {
                NavRowLabel(title: "Edit statuses", icon: "pencil", color: .green)
            }
            .buttonStyle(.plain)
        }
    }

    private var colorsCard: some View {
        Card(title: "Colors", icon: "paintpalette.fill", tint: .orange,
             footer: "The accent colors the outline, glow, buttons, Lock Screen tint and every slot set to follow it. Pick where it comes from to make your whole island change color on its own.") {
            ColorField(title: manager.config.accentSync == .fixed ? "Accent color" : "Accent color (synced)",
                       icon: "drop.fill", iconColor: .orange, hex: $manager.config.keylineHex)
                .disabled(manager.config.accentSync != .fixed)
            RowDivider()
            HStack(spacing: 10) {
                IconBadge(systemName: "arrow.triangle.2.circlepath", color: .teal)
                Text("Accent comes from")
                Spacer()
                Picker("Accent comes from", selection: $manager.config.accentSync) {
                    ForEach(AccentSync.allCases) { sync in
                        Label(sync.label, systemImage: sync.icon).tag(sync)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            RowDivider()
            ToggleRow(title: "All slots follow accent", icon: "link", color: .indigo, isOn: followBinding)
            RowDivider()
            Text("Harmony").font(.subheadline.weight(.medium))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HarmonyKind.allCases) { kind in
                        PillButton(title: kind.label, icon: "circle.hexagongrid.fill") {
                            manager.applyHarmony(kind)
                        }
                    }
                }
            }
            Text("Recolors your slots with colors that go with your accent.")
                .font(.caption)
                .foregroundStyle(.secondary)
            RowDivider()
            Text("Palettes").font(.subheadline.weight(.medium))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ColorPalette.all) { palette in
                        PaletteChip(palette: palette) { manager.applyPalette(palette) }
                    }
                }
            }
            RowDivider()
            PhotosPicker(selection: $paletteItem, matching: .images) {
                Label("Pick colors from a photo", systemImage: "eyedropper.halffull")
                    .font(.subheadline.weight(.semibold))
            }
            if !photoPalette.isEmpty {
                HStack(spacing: 10) {
                    ForEach(photoPalette, id: \.self) { hex in
                        Button {
                            manager.config.accentSync = .fixed
                            manager.config.keylineHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Button("Use all") {
                        manager.applyPalette(ColorPalette(id: "photo", name: "Photo", colors: photoPalette))
                    }
                    .font(.subheadline.weight(.semibold))
                }
                Text("Tap a color to make it your accent, or use all of them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func layoutCard(_ snapshot: IslandState) -> some View {
        Card(title: "Layout", icon: "rectangle.split.3x1.fill", tint: .blue,
             footer: "Each slot has its own content, colors, size, shape and motion. The minimal bubble shows when another app, like FaceTime, takes the main island.") {
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
            RowDivider()
            HStack(spacing: 10) {
                WideButton(title: "Left look → right", icon: "arrow.right") {
                    manager.copySlotStyle(from: \.left, to: \.right)
                }
                WideButton(title: "Right look → left", icon: "arrow.left") {
                    manager.copySlotStyle(from: \.right, to: \.left)
                }
            }
        }
    }

    private func menuRow<P: View>(_ title: String, icon: String, color: Color,
                                  @ViewBuilder picker: () -> P) -> some View {
        HStack(spacing: 10) {
            IconBadge(systemName: icon, color: color)
            Text(title)
            Spacer()
            picker()
                .pickerStyle(.menu)
                .labelsHidden()
        }
    }

    private var textCard: some View {
        Card(title: "Text & glow", icon: "textformat", tint: .pink,
             footer: "iOS only draws the island's own outline faintly, in Dark Mode. Neon glow makes your icons and text glow, which you can actually see.") {
            menuRow("Font", icon: "textformat", color: .indigo) {
                Picker("Font", selection: $manager.config.fontDesign) {
                    Text("Default").tag("default")
                    Text("Rounded").tag("rounded")
                    Text("Mono").tag("monospaced")
                    Text("Serif").tag("serif")
                }
            }
            RowDivider()
            menuRow("Weight", icon: "bold", color: .gray) {
                Picker("Weight", selection: weightBinding) {
                    ForEach(weights, id: \.self) { weight in
                        Text(weight.capitalized).tag(weight)
                    }
                }
            }
            RowDivider()
            menuRow("Width", icon: "arrow.left.and.right", color: .blue) {
                Picker("Width", selection: $manager.config.fontWidth) {
                    Text("Standard").tag("standard")
                    Text("Condensed").tag("condensed")
                    Text("Compressed").tag("compressed")
                    Text("Expanded").tag("expanded")
                }
            }
            RowDivider()
            menuRow("Clock format", icon: "clock", color: .teal) {
                Picker("Clock format", selection: $manager.config.clockMode) {
                    Text("Match iPhone").tag("auto")
                    Text("12-hour").tag("12")
                    Text("24-hour").tag("24")
                }
            }
            RowDivider()
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Letter spacing")
                    Spacer()
                    Text(String(format: "%.1f", manager.config.tracking)).foregroundStyle(.secondary)
                }
                Slider(value: $manager.config.tracking, in: -1...4, step: 0.5)
            }
            RowDivider()
            ToggleRow(title: "Outline ring on minimal bubble", icon: "circle.dashed", color: .cyan,
                      isOn: $manager.config.minimalRing)
            RowDivider()
            ToggleRow(title: "Neon glow", icon: "sparkle", color: .pink, isOn: $manager.config.glow)
            if manager.config.glow {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Glow strength")
                        Spacer()
                        Text("\(Int((manager.config.glowStrength * 100).rounded()))%").foregroundStyle(.secondary)
                    }
                    Slider(value: $manager.config.glowStrength, in: 0.3...2, step: 0.1)
                }
            }
        }
    }

    private var backgroundCard: some View {
        Card(title: "Island background", icon: "rectangle.inset.filled", tint: .indigo,
             footer: "iOS keeps the island itself pure black so it blends into the camera, and apps can't change that. This adds a colored backing behind your icons and text, and inside the long-press view, using your accent color.") {
            Picker("Background", selection: $manager.config.islandBg) {
                ForEach(IslandBG.allCases) { bg in
                    Text(bg.label).tag(bg)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var animationCard: some View {
        Card(title: "Animation", icon: "waveform.path.ecg", tint: .teal,
             footer: "Step speed is how often the island moves. Each slot can also have its own motion in its editor.") {
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
    }

    private var photoCard: some View {
        Card(title: "My photo", icon: "photo.fill", tint: .green,
             footer: "Set any slot to My photo to use it. It's shrunk to a tiny icon to fit iOS's 4 KB limit. For several photos, use Photo slideshow in Settings → Tools.") {
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

    private func loadPalette(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                let colors = PaletteExtractor.palette(from: image)
                photoPalette = colors
                if colors.isEmpty { manager.status = "Couldn't read colors from that photo" }
            }
        }
    }
}

// MARK: Expanded tab

struct ExpandedSettings: View {
    @EnvironmentObject var manager: IslandManager

    private func buttonBinding(_ index: Int) -> Binding<String> {
        Binding(get: {
            let buttons = manager.settings.expandedButtons
            return index < buttons.count ? buttons[index] : "none"
        }, set: { newValue in
            var slots = (0..<3).map { i -> String in
                let buttons = manager.settings.expandedButtons
                return i < buttons.count ? buttons[i] : "none"
            }
            slots[index] = newValue
            manager.settings.expandedButtons = slots
        })
    }

    var body: some View {
        VStack(spacing: 16) {
            Card(title: "Layout", icon: "rectangle.expand.vertical", tint: .blue,
                 footer: "Long-press the island to see the expanded view.") {
                Picker("Layout", selection: $manager.config.expandedLayout) {
                    ForEach(ExpandedLayout.allCases) { layout in
                        Text(layout.label).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
            }

            Card(title: "Title", icon: "textformat", tint: .indigo) {
                TextField("Title", text: $manager.config.expandedTitle)
                    .cardField()
                TextField("Subtitle", text: $manager.config.expandedSubtitle)
                    .cardField()
                ToggleRow(title: "Custom title color", icon: "paintbrush.fill", color: .pink,
                          isOn: manager.customColorToggle(\.expandedTitleHex))
                if !manager.config.expandedTitleHex.isEmpty {
                    ColorField(title: "Title color", hex: $manager.config.expandedTitleHex)
                }
                Text("Title icon").font(.subheadline.weight(.medium))
                IconStrip(symbol: $manager.config.expandedIcon)
            }

            Card(title: "Buttons", icon: "hand.tap.fill", tint: .purple,
                 footer: "Pick up to three. Music buttons control the built-in Music app.") {
                ToggleRow(title: "Show buttons", icon: "eye.fill", color: .purple,
                          isOn: $manager.settings.showIslandButtons)
                if manager.settings.showIslandButtons {
                    ForEach(0..<3, id: \.self) { index in
                        RowDivider()
                        HStack {
                            Text("Button \(index + 1)")
                            Spacer()
                            Picker("Button \(index + 1)", selection: buttonBinding(index)) {
                                Text("None").tag("none")
                                ForEach(ButtonKind.allCases) { kind in
                                    Label(kind.label, systemImage: kind.icon).tag(kind.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                }
            }

            Card(title: "Reactions", icon: "face.smiling", tint: .pink,
                 footer: "Long-press the island and tap an emoji to pop it out. Handy for showing someone your phone, or just for fun.") {
                ToggleRow(title: "Emoji reaction row", icon: "face.smiling", color: .pink,
                          isOn: $manager.settings.showReactions)
                if manager.settings.showReactions {
                    ReactionEditor()
                }
            }

            Card(title: "Extras", icon: "square.stack.3d.up.fill", tint: .teal,
                 footer: "Info chips and the progress bar are shared with the Lock Screen. Pick up to four chips so they fit.") {
                ToggleRow(title: "Counter + / − row", icon: "plus.circle.fill", color: .blue,
                          isOn: $manager.settings.counterButtons)
                RowDivider()
                ToggleRow(title: "Info chips", icon: "square.grid.2x2.fill", color: .teal,
                          isOn: $manager.config.expandedChips)
                if manager.config.expandedChips {
                    ChipPicker(kinds: $manager.config.chipKinds)
                    NavigationLink {
                        ChipOrderView(kinds: $manager.config.chipKinds)
                    } label: {
                        NavRowLabel(title: "Reorder chips", icon: "arrow.up.arrow.down", color: .teal,
                                    value: "\(manager.config.chipKinds.count) showing")
                    }
                    .buttonStyle(.plain)
                }
                RowDivider()
                ToggleRow(title: "Progress bar", icon: "minus.rectangle.fill", color: .orange,
                          isOn: $manager.config.expandedBar)
                if manager.config.expandedBar {
                    BarStylePicker(style: $manager.config.lockBarStyle)
                }
            }

            Card(title: "Pop-outs", icon: "bell.badge.fill", tint: .orange,
                 footer: "Pop-outs briefly expand the island on their own. Headphones show the device name, because iOS doesn't share AirPods battery with apps. After tapping Test, swipe home within 5 seconds.") {
                ToggleRow(title: "Charging pop-out", icon: "bolt.fill", color: .green,
                          isOn: $manager.settings.chargingMode)
                RowDivider()
                ToggleRow(title: "Charging look while plugged in", icon: "battery.100.bolt", color: .mint,
                          isOn: $manager.settings.chargingTakeover)
                RowDivider()
                ToggleRow(title: "Low battery alert", icon: "battery.25", color: .red,
                          isOn: $manager.settings.lowBatteryAlert)
                RowDivider()
                ToggleRow(title: "Headphones connected", icon: "headphones", color: .pink,
                          isOn: $manager.settings.headphonesPopOut)
                RowDivider()
                ToggleRow(title: "Hourly pop-out", icon: "clock.fill", color: .orange,
                          isOn: $manager.settings.hourlyPopOut)
                RowDivider()
                ToggleRow(title: "Play sound", icon: "speaker.wave.2.fill", color: .purple,
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
                 footer: "Compact is one slim row and skips chips and the progress bar. Big clock makes the time the star.") {
                Picker("Layout", selection: $manager.config.lockLayout) {
                    ForEach(LockLayout.allCases) { layout in
                        Text(layout.label).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Text alignment", selection: $manager.config.lockAlign) {
                    Text("Left").tag("leading")
                    Text("Center").tag("center")
                }
                .pickerStyle(.segmented)
            }

            Card(title: "Background", icon: "circle.lefthalf.filled", tint: .purple,
                 footer: "Tinted and Gradient use your accent color. Glass lets your wallpaper show through. Custom is your own two-color gradient. Aurora slowly drifts through colors on its own.") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LockStyle.allCases) { style in
                            FilterChip(title: style.label, selected: manager.config.lockStyle == style) {
                                manager.config.lockStyle = style
                            }
                        }
                    }
                }
                if manager.config.lockStyle == .custom {
                    ColorField(title: "Top color", hex: $manager.config.lockBgHex)
                    ColorField(title: "Bottom color", hex: $manager.config.lockBg2Hex)
                }
            }

            Card(title: "Icon badges", icon: "app.badge.fill", tint: .pink) {
                Picker("Badges", selection: $manager.config.badgeStyle) {
                    ForEach(BadgeStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }

            Card(title: "Text", icon: "textformat", tint: .indigo) {
                ToggleRow(title: "Own Lock Screen text", icon: "lock.fill", color: .indigo,
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
                RowDivider()
                ToggleRow(title: "Custom title color", icon: "paintbrush.fill", color: .pink,
                          isOn: manager.customColorToggle(\.lockTitleHex))
                if !manager.config.lockTitleHex.isEmpty {
                    ColorField(title: "Title color", hex: $manager.config.lockTitleHex)
                }
                Text("Title icon").font(.subheadline.weight(.medium))
                IconStrip(symbol: $manager.config.lockIcon)
            }

            Card(title: "Mini graph", icon: "chart.xyaxis.line", tint: .green,
                 footer: "A tiny chart of your battery over the last 12 hours, or your steps today. It fills in as the app collects readings, so give it a few minutes.") {
                Picker("Graph", selection: $manager.config.graphKind) {
                    Text("Off").tag("")
                    Text("Battery").tag("battery")
                    Text("Steps").tag("steps")
                }
                .pickerStyle(.segmented)
            }

            Card(title: "Extras", icon: "sparkles", tint: .teal,
                 footer: "Chips appear in the order you tap them; pick up to four so they fit. Chips without data yet (like weather before you set a location) stay hidden.") {
                ToggleRow(title: "Info chips", icon: "square.grid.2x2.fill", color: .teal,
                          isOn: $manager.config.lockChips)
                if manager.config.lockChips {
                    ChipPicker(kinds: $manager.config.chipKinds)
                    NavigationLink {
                        ChipOrderView(kinds: $manager.config.chipKinds)
                    } label: {
                        NavRowLabel(title: "Reorder chips", icon: "arrow.up.arrow.down", color: .teal,
                                    value: "\(manager.config.chipKinds.count) showing")
                    }
                    .buttonStyle(.plain)
                }
                RowDivider()
                ToggleRow(title: "Progress bar", icon: "minus.rectangle.fill", color: .orange,
                          isOn: $manager.config.lockAccent)
                if manager.config.lockAccent {
                    BarStylePicker(style: $manager.config.lockBarStyle)
                }
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
