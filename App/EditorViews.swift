import SwiftUI

// MARK: - Pinned live preview (stays on screen while you scroll)

enum PreviewMode: String, CaseIterable, Identifiable {
    case island, expanded, lock

    var id: String { rawValue }

    var label: String {
        switch self {
        case .island: return "Island"
        case .expanded: return "Expanded"
        case .lock: return "Lock Screen"
        }
    }
}

extension View {
    /// Pins the live preview under the navigation bar, above the scrolling settings.
    /// `music: true` makes the preview show the music layout while this screen is open.
    func pinnedPreview(music: Bool = false) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            PinnedPreview(music: music)
        }
    }
}

struct PinnedPreview: View {
    @EnvironmentObject var manager: IslandManager
    @AppStorage("previewMode") private var previewMode = PreviewMode.island.rawValue
    var music = false

    private var mode: PreviewMode { PreviewMode(rawValue: previewMode) ?? .island }

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                PreviewStage(mode: mode, state: manager.previewState(at: ctx.date, music: music))
            }
            .frame(height: 128)

            Picker("Preview", selection: $previewMode) {
                ForEach(PreviewMode.allCases) { m in
                    Text(m.label).tag(m.rawValue)
                }
            }
            .pickerStyle(.segmented)

            StatusLine()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

struct StatusLine: View {
    @EnvironmentObject var manager: IslandManager
    @Environment(\.themeAccent) private var accent

    private var dotColor: Color {
        if !manager.isRunning { return .gray }
        if manager.isHiddenForMusic { return .orange }
        return manager.paused ? .yellow : .green
    }

    private var stateText: String {
        if !manager.isRunning { return "Off" }
        if manager.isHiddenForMusic { return "Hidden for music" }
        return manager.paused ? "Paused" : "Live"
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dotColor).frame(width: 7, height: 7)
            Text(stateText).font(.caption.weight(.semibold))
            if !manager.status.isEmpty {
                Text("· \(manager.status)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                Task {
                    if manager.isRunning {
                        await manager.stop()
                    } else {
                        await manager.start()
                    }
                }
            } label: {
                Text(manager.isRunning ? "Stop" : "Start")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(manager.isRunning ? Color.red.opacity(0.85) : accent))
            }
            .buttonStyle(.plain)
        }
        .animation(.easeInOut(duration: 0.2), value: manager.status)
    }
}

struct PreviewStage: View {
    let mode: PreviewMode
    let state: IslandState
    @Environment(\.themeAccent) private var accent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [accent.opacity(0.45), Color(red: 0.05, green: 0.05, blue: 0.09)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.35))

            switch mode {
            case .island:
                VStack(spacing: 8) {
                    IslandPreview(state: state)
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 150, height: 30)
                            .overlay(alignment: .leading) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.green)
                                    .padding(.leading, 14)
                            }
                        CompactSlot(slot: state.minimal, state: state, size: 17, minimal: true)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.black))
                    }
                    Text("On its own (top) · sharing with a call (bottom)")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.55))
                }

            case .expanded:
                ExpandedPreview(state: state)
                    .scaleEffect(0.88)

            case .lock:
                LockScreenView(state: state)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(state.lockBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 10)
                    .scaleEffect(state.lockLayout == .hero ? 0.74 : 0.86)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// The compact island, drawn in the app. The outline is faint on purpose: that's how iOS draws it.
struct IslandPreview: View {
    let state: IslandState

    var body: some View {
        HStack(spacing: 0) {
            CompactSlot(slot: state.left, state: state, size: 20)
                .frame(width: 72, alignment: .leading)
            Spacer(minLength: 90)
            CompactSlot(slot: state.right, state: state, size: 20)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(width: 300, height: 38)
        .background(Capsule().fill(Color.black))
        .overlay(Capsule().strokeBorder(Color(hex: state.keylineHex).opacity(0.25), lineWidth: 0.75))
        .environment(\.colorScheme, .dark)
        .padding(.vertical, 8)
    }
}

/// The long-press island, drawn in the app.
struct ExpandedPreview: View {
    let state: IslandState

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                SlotView(slot: state.left, state: state, size: state.expandedSlotSize * 0.88)
                    .islandPanel(state)
                    .frame(width: 84, alignment: .leading)
                Spacer(minLength: 0)
                ExpandedTitle(state: state)
                Spacer(minLength: 0)
                SlotView(slot: state.right, state: state, size: state.expandedSlotSize * 0.88)
                    .islandPanel(state)
                    .frame(width: 84, alignment: .trailing)
            }
            ExpandedBottom(state: state)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 350)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Color.black))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous)
            .strokeBorder(Color(hex: state.keylineHex).opacity(0.25), lineWidth: 0.75))
    }
}

// MARK: - Slot editor

struct SlotEditor: View {
    @EnvironmentObject var manager: IslandManager
    @AppStorage("previewMode") private var previewMode = PreviewMode.island.rawValue
    @Environment(\.themeAccent) private var accent
    let title: String
    @Binding var slot: SlotConfig
    var music = false

    private let quickSymbols = ["heart.fill", "star.fill", "bolt.fill", "flame.fill", "moon.fill",
                                "sparkles", "music.note", "car.fill", "gamecontroller.fill",
                                "leaf.fill", "crown.fill", "circle.fill", "sun.max.fill", "cloud.fill",
                                "pawprint.fill", "headphones", "snowflake", "drop.fill", "moon.stars.fill",
                                "steeringwheel"]

    private var hasMotionSpeed: Bool {
        slot.anim != .none || slot.content == .pulse || slot.content == .spin || slot.content == .rainbow
    }

    private var thirdColor: Binding<Bool> {
        Binding(get: { !slot.color3Hex.isEmpty },
                set: { slot.color3Hex = $0 ? "FFD60AFF" : "" })
    }

    var body: some View {
        Form {
            Section {
                Picker("Show", selection: $slot.content) {
                    ForEach(SlotCategory.allCases) { category in
                        Section(category.title) {
                            ForEach(category.items) { item in
                                Label(item.label, systemImage: item.icon).tag(item)
                            }
                        }
                    }
                }
                .pickerStyle(.navigationLink)
                if let hint = slot.content.hint {
                    Text(hint).font(.footnote).foregroundStyle(.secondary)
                }
            }

            if slot.content.usesText {
                Section("Text") {
                    TextField(slot.content.textPlaceholder, text: $slot.text)
                }
            }

            if slot.content.usesSymbol {
                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(quickSymbols, id: \.self) { name in
                                Button {
                                    slot.symbol = name
                                } label: {
                                    Image(systemName: name)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(slot.symbol == name ? accent.opacity(0.25)
                                                                          : Color(.tertiarySystemFill))
                                        )
                                        .foregroundStyle(slot.symbol == name ? accent : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    TextField("Or type any SF Symbol name", text: $slot.symbol)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            if slot.content.usesColor {
                colorSection
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Size")
                        Spacer()
                        Text("\(Int((slot.scale * 100).rounded()))%").foregroundStyle(.secondary)
                    }
                    Slider(value: $slot.scale, in: 0.6...1.6, step: 0.05)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Nudge sideways")
                        Spacer()
                        Text("\(Int(slot.offsetX)) pt").foregroundStyle(.secondary)
                    }
                    Slider(value: $slot.offsetX, in: -12...12, step: 1)
                }
                Picker("Shape", selection: $slot.shape) {
                    ForEach(SlotShape.allCases) { shape in
                        Text(shape.label).tag(shape)
                    }
                }
                .pickerStyle(.segmented)
                if slot.scale != 1 || slot.offsetX != 0 {
                    Button("Reset size and position") {
                        slot.scale = 1
                        slot.offsetX = 0
                    }
                }
            } header: {
                Text("Size, position & shape")
            } footer: {
                Text("Shapes add a soft colored backing behind the slot. Big sizes can get clipped by the island's edges.")
            }

            Section {
                Picker("Animation", selection: $slot.anim) {
                    ForEach(SlotAnim.allCases) { anim in
                        Text(anim.label).tag(anim)
                    }
                }
                if hasMotionSpeed {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Speed")
                            Spacer()
                            Text(String(format: "%.2gx", slot.speed)).foregroundStyle(.secondary)
                        }
                        Slider(value: $slot.speed, in: 0.5...2, step: 0.25)
                    }
                }
            } header: {
                Text("Motion")
            } footer: {
                Text("Adds movement to anything in this slot. Speed also changes the Pulse, Spin and Rainbow slots.")
            }
        }
        .themedForm()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview(music: music)
        .onAppear { previewMode = PreviewMode.island.rawValue }
        .onChange(of: slot.content) { _, newValue in
            // Weather and crypto look best in their natural, live colors.
            if newValue == .weather || newValue == .crypto { slot.colorMode = .live }
        }
    }

    @ViewBuilder private var colorSection: some View {
        Section {
            Toggle("Follow accent color", isOn: $slot.useAccent)
            if !slot.useAccent {
                Picker("Color style", selection: $slot.colorMode) {
                    ForEach(ColorMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                ColorPicker(slot.colorMode == .gradient || slot.colorMode == .cycle ? "First color" : "Color",
                            selection: colorBinding(\.colorHex))
                if slot.colorMode == .gradient || slot.colorMode == .cycle {
                    ColorPicker("Second color", selection: colorBinding(\.color2Hex))
                    Toggle("Add a third color", isOn: thirdColor)
                    if !slot.color3Hex.isEmpty {
                        ColorPicker("Third color", selection: colorBinding(\.color3Hex))
                    }
                }
                if slot.colorMode == .gradient {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Angle")
                            Spacer()
                            Text("\(Int(slot.gradientAngle))°").foregroundStyle(.secondary)
                        }
                        Slider(value: $slot.gradientAngle, in: 0...360, step: 15)
                    }
                }
            }
        } header: {
            Text("Color")
        } footer: {
            Text(slot.useAccent
                 ? "This slot uses the accent color, so it changes whenever the accent does (including synced accents)."
                 : "Gradient blends your colors at any angle. Cycle switches between them every step. Live uses natural colors: weather shows real conditions, crypto goes green or red, the focus timer changes by phase.")
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<SlotConfig, String>) -> Binding<Color> {
        Binding(get: { Color(hex: slot[keyPath: keyPath]) },
                set: { slot[keyPath: keyPath] = $0.hexString })
    }
}

// MARK: - Rows, tiles and cards

struct SlotRow: View {
    let title: String
    let slot: SlotConfig

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Label(slot.content.label, systemImage: slot.content.icon)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }
}

/// Card row for a slot: live mini render, name, current content.
struct SlotNavLabel: View {
    let title: String
    let slot: SlotConfig
    let state: IslandState

    var body: some View {
        HStack(spacing: 12) {
            SlotView(slot: slot, state: state, size: 16, decorated: false)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.black))
                .environment(\.colorScheme, .dark)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(slot.content.label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

/// Small preset button with a mini island (used in the Studio strip).
struct PresetTile: View {
    let preset: SavedPreset
    let isCurrent: Bool
    let state: IslandState
    let action: () -> Void
    @Environment(\.themeAccent) private var accent

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                IslandPreview(state: state)
                    .scaleEffect(0.4)
                    .frame(width: 120, height: 24)
                Text(preset.name).font(.caption.weight(.medium)).lineLimit(1)
            }
            .frame(width: 132, height: 70)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.tertiarySystemFill)))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isCurrent ? accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Large preset card for the Presets gallery.
struct PresetCard: View {
    let preset: SavedPreset
    let category: String
    let isCurrent: Bool
    let state: IslandState
    var isDefault = false
    var isFavorite = false
    let action: () -> Void
    @Environment(\.themeAccent) private var accent

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.17, blue: 0.24),
                                                      Color(red: 0.05, green: 0.05, blue: 0.08)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    IslandPreview(state: state)
                        .scaleEffect(0.46)
                        .frame(width: 140, height: 26)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if isDefault {
                        Image(systemName: "house.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Circle().fill(accent))
                            .padding(6)
                    }
                }
                .frame(height: 64)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(preset.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            if isFavorite {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(Color.yellow)
                            }
                        }
                        Text(isDefault ? "Default · \(category)" : category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.regularMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isCurrent ? accent : Color.primary.opacity(0.07), lineWidth: isCurrent ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
