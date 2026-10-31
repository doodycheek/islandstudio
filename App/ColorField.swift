import SwiftUI

/// A color row with the iOS picker (including opacity), a hex box, and your saved "My colors".
struct ColorField: View {
    @EnvironmentObject var manager: IslandManager
    let title: String
    var icon: String? = nil
    var iconColor: Color = .orange
    @Binding var hex: String
    @State private var draft = ""
    @FocusState private var editing: Bool

    private var colorBinding: Binding<Color> {
        Binding(get: { Color(hex: hex) }, set: { hex = $0.hexString })
    }

    /// Six digits when fully opaque, eight when it has transparency.
    private func shown(_ value: String) -> String {
        let clean = value.uppercased()
        if clean.count == 8 && clean.hasSuffix("FF") { return String(clean.prefix(6)) }
        return clean
    }

    private func apply(_ text: String) {
        let allowed = Set("0123456789ABCDEF")
        let clean = String(text.uppercased().filter { allowed.contains($0) })
        if clean.count == 6 {
            hex = clean + "FF"
        } else if clean.count == 8 {
            hex = clean
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ColorPicker(selection: colorBinding) {
                HStack(spacing: 10) {
                    if let icon {
                        IconBadge(systemName: icon, color: iconColor)
                    }
                    Text(title)
                }
            }
            HStack(spacing: 8) {
                Text("#").foregroundStyle(.secondary)
                TextField("RRGGBB or RRGGBBAA", text: $draft)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($editing)
                    .onChange(of: draft) { _, newValue in
                        if editing { apply(newValue) }
                    }
                Button {
                    manager.saveColor(hex)
                } label: {
                    Label("Save", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
            .cardField()
            if !manager.settings.savedColors.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Text("My colors").font(.caption).foregroundStyle(.secondary)
                        ForEach(manager.settings.savedColors, id: \.self) { saved in
                            Button {
                                hex = saved
                            } label: {
                                Circle()
                                    .fill(Color(hex: saved))
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    manager.deleteSavedColor(saved)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { draft = shown(hex) }
        .onChange(of: hex) { _, newValue in
            if !editing { draft = shown(newValue) }
        }
    }
}

enum HarmonyKind: String, CaseIterable, Identifiable {
    case complementary, analogous, triadic, split

    var id: String { rawValue }

    var label: String {
        switch self {
        case .complementary: return "Opposite"
        case .analogous: return "Neighbors"
        case .triadic: return "Triangle"
        case .split: return "Split"
        }
    }

    /// How far around the color wheel to move from your accent.
    var shifts: [Double] {
        switch self {
        case .complementary: return [0.5]
        case .analogous: return [-0.083, 0.083]
        case .triadic: return [0.333, 0.667]
        case .split: return [0.417, 0.583]
        }
    }
}

extension IslandManager {
    func saveColor(_ hex: String) {
        guard !hex.isEmpty, !settings.savedColors.contains(hex) else {
            status = "Already in My colors"
            return
        }
        settings.savedColors.insert(hex, at: 0)
        if settings.savedColors.count > 20 { settings.savedColors.removeLast() }
        Haptics.tap()
        status = "Saved to My colors"
    }

    func deleteSavedColor(_ hex: String) {
        settings.savedColors.removeAll { $0 == hex }
    }

    /// Recolors the three slots with colors that go well with your accent.
    func applyHarmony(_ kind: HarmonyKind) {
        let base = Color(hex: config.keylineHex)
        let shifts = kind.shifts
        let first = base.hueShifted(shifts[0]).hexString
        let last = base.hueShifted(shifts[shifts.count - 1]).hexString
        var s = config
        s.left.useAccent = false
        s.left.colorHex = base.hexString
        s.left.color2Hex = last
        s.right.useAccent = false
        s.right.colorHex = first
        s.right.color2Hex = last
        s.minimal.useAccent = false
        s.minimal.colorHex = base.hexString
        s.minimal.color2Hex = first
        config = s
        status = "Applied \(kind.label.lowercased()) colors"
    }

    /// Copies one slot's look (colors, size, shape, motion, text effects) onto another. Content stays.
    func copySlotStyle(from source: WritableKeyPath<IslandState, SlotConfig>,
                       to target: WritableKeyPath<IslandState, SlotConfig>) {
        let a = config[keyPath: source]
        var b = config[keyPath: target]
        b.colorHex = a.colorHex
        b.color2Hex = a.color2Hex
        b.color3Hex = a.color3Hex
        b.colorMode = a.colorMode
        b.gradientAngle = a.gradientAngle
        b.useAccent = a.useAccent
        b.scale = a.scale
        b.offsetX = a.offsetX
        b.shape = a.shape
        b.anim = a.anim
        b.speed = a.speed
        b.badge = a.badge
        b.badgeHex = a.badgeHex
        b.caseStyle = a.caseStyle
        b.textShadow = a.textShadow
        b.textSpeed = a.textSpeed
        config[keyPath: target] = b
        status = "Copied the look"
        Haptics.tap()
    }

    func putMineFirst() {
        let mine = savedPresets.reversed().map { $0.id }
        let rest = PresetStore.builtIns.map { $0.id }
        settings.presetOrder = mine + rest
        status = "Your presets are first"
    }
}

/// The small-bubble switch with its timer, used in Studio and Settings.
struct BubbleControls: View {
    @EnvironmentObject var manager: IslandManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ToggleRow(title: "Stay in the small bubble", icon: "circle.dashed", color: .pink,
                      isOn: Binding(get: { manager.settings.stayInBubble },
                                    set: { manager.setBubbleMode($0) }))
            HStack {
                Text("Turn off after")
                Spacer()
                Picker("Turn off after", selection: $manager.settings.bubbleHours) {
                    Text("Until I turn it off").tag(0)
                    Text("1 hour").tag(1)
                    Text("2 hours").tag(2)
                    Text("4 hours").tag(4)
                    Text("8 hours").tag(8)
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            if manager.settings.stayInBubble {
                if let end = manager.settings.bubbleUntil {
                    Text("Turns itself off at " + end.formatted(date: .omitted, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Refresh every")
                    Spacer()
                    Picker("Refresh every", selection: $manager.settings.bubbleSeconds) {
                        Text("15 seconds").tag(15.0)
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                        Text("2 minutes").tag(120.0)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }
}
