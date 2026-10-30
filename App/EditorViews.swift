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
    func pinnedPreview() -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            PinnedPreview()
        }
    }
}

struct PinnedPreview: View {
    @EnvironmentObject var manager: IslandManager
    @AppStorage("previewMode") private var previewMode = PreviewMode.island.rawValue

    private var mode: PreviewMode { PreviewMode(rawValue: previewMode) ?? .island }

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                PreviewStage(mode: mode, state: manager.previewState(at: ctx.date))
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
            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.2), value: manager.status)
    }
}

struct PreviewStage: View {
    let mode: PreviewMode
    let state: IslandState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.17, green: 0.18, blue: 0.26),
                                              Color(red: 0.05, green: 0.05, blue: 0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))

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
                        SlotView(slot: state.minimal, state: state, size: 17)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.black))
                    }
                    Text("On its own (top) · sharing with a call (bottom)")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.5))
                }

            case .expanded:
                ExpandedPreview(state: state)
                    .scaleEffect(0.88)

            case .lock:
                LockScreenView(state: state)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(state.lockBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 10)
                    .scaleEffect(0.86)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// The compact island, drawn in the app.
struct IslandPreview: View {
    let state: IslandState

    var body: some View {
        HStack(spacing: 0) {
            SlotView(slot: state.left, state: state, size: 20)
                .frame(width: 72, alignment: .leading)
            Spacer(minLength: 90)
            SlotView(slot: state.right, state: state, size: 20)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(width: 300, height: 38)
        .background(Capsule().fill(Color.black))
        .overlay(Capsule().strokeBorder(Color(hex: state.keylineHex).opacity(0.5), lineWidth: 1))
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
                SlotView(slot: state.left, state: state, size: 30)
                    .frame(width: 80, alignment: .leading)
                Spacer(minLength: 0)
                ExpandedTitle(state: state)
                Spacer(minLength: 0)
                SlotView(slot: state.right, state: state, size: 30)
                    .frame(width: 80, alignment: .trailing)
            }
            ExpandedBottom(state: state)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 350)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Color.black))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous)
            .strokeBorder(Color(hex: state.keylineHex).opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Slot editor

struct SlotEditor: View {
    @EnvironmentObject var manager: IslandManager
    @AppStorage("previewMode") private var previewMode = PreviewMode.island.rawValue
    let title: String
    @Binding var slot: SlotConfig

    private let quickSymbols = ["heart.fill", "star.fill", "bolt.fill", "flame.fill", "moon.fill",
                                "sparkles", "music.note", "car.fill", "gamecontroller.fill",
                                "leaf.fill", "crown.fill", "circle.fill", "sun.max.fill", "cloud.fill",
                                "pawprint.fill", "headphones"]

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
                                                .fill(slot.symbol == name ? Color.accentColor.opacity(0.25)
                                                                          : Color(.tertiarySystemFill))
                                        )
                                        .foregroundStyle(slot.symbol == name ? Color.accentColor : Color.primary)
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
                Section {
                    Picker("Color style", selection: $slot.colorMode) {
                        ForEach(ColorMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    ColorPicker(slot.colorMode == .solid ? "Color" : "First color",
                                selection: colorBinding(\.colorHex))
                    if slot.colorMode != .solid {
                        ColorPicker("Second color", selection: colorBinding(\.color2Hex))
                    }
                } header: {
                    Text("Color")
                } footer: {
                    Text("Gradient blends the two colors. Cycle switches between them on every animation step.")
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview()
        .onAppear { previewMode = PreviewMode.island.rawValue }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<SlotConfig, String>) -> Binding<Color> {
        Binding(get: { Color(hex: slot[keyPath: keyPath]) },
                set: { slot[keyPath: keyPath] = $0.hexString })
    }
}

// MARK: - Rows and tiles

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

/// A preset button that shows a mini version of the island it applies.
struct PresetTile: View {
    let preset: SavedPreset
    let isCurrent: Bool
    let state: IslandState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                IslandPreview(state: state)
                    .scaleEffect(0.4)
                    .frame(width: 120, height: 24)
                HStack(spacing: 4) {
                    Image(systemName: preset.icon).font(.caption2)
                    Text(preset.name).font(.caption.weight(.medium)).lineLimit(1)
                }
            }
            .frame(width: 132, height: 72)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isCurrent ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
