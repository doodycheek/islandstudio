import AudioToolbox
import AVFoundation
import SwiftUI

// MARK: - Always-On Display editor

/// Settings for how your Lock Screen card looks when your iPhone sleeps on the Always-On Display.
struct AODSettings: View {
    @EnvironmentObject var manager: IslandManager

    var body: some View {
        VStack(spacing: 16) {
            Card(title: "Always-On layout", icon: "moon.zzz.fill", tint: .indigo,
                 footer: "Classic keeps your slots and title. Big clock makes the time huge. Minimal is just a small time and your two slots.") {
                SegmentedPills(selection: $manager.config.aodLayout,
                               options: [("classic", "Classic"), ("clock", "Big clock"), ("minimal", "Minimal")])
            }

            Card(title: "What shows", icon: "eye.fill", tint: .teal) {
                ToggleRow(title: "Show seconds", icon: "clock.badge.checkmark", color: .orange,
                          isOn: $manager.config.aodSeconds)
                RowDivider()
                ToggleRow(title: "Tint the time with my accent", icon: "paintpalette.fill", color: .pink,
                          isOn: $manager.config.aodTint)
                RowDivider()
                ToggleRow(title: "Info chips", icon: "square.grid.2x2.fill", color: .teal,
                          isOn: $manager.config.aodChips)
            }

            Card(title: "Good to know", icon: "info.circle.fill", tint: .gray) {
                Text("iOS dims the Always-On screen and only refreshes it about once a second, so seconds can skip. It also mutes colors, so your slots switch to bright white there. Ticking timers become plain digits so they never turn into long text.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Long-press view order

struct ExpandedOrderView: View {
    @EnvironmentObject var manager: IslandManager

    private let names: [String: (String, String)] = [
        "subtitle": ("Subtitle", "text.alignleft"),
        "chips": ("Info chips", "square.grid.2x2.fill"),
        "bar": ("Accent bar", "minus.rectangle.fill"),
        "graph": ("Mini graph", "chart.xyaxis.line"),
        "reactions": ("Emoji reactions", "face.smiling"),
        "counter": ("Counter buttons", "plus.circle.fill"),
        "timer": ("Focus button", "timer"),
        "buttons": ("Preset buttons", "hand.tap.fill"),
        "links": ("Quick launch", "bolt.horizontal.fill")
    ]

    private var order: [String] {
        var list = manager.config.expandedOrder.filter { ExpandedBottom.defaultOrder.contains($0) }
        for key in ExpandedBottom.defaultOrder where !list.contains(key) { list.append(key) }
        return list
    }

    var body: some View {
        List {
            Section {
                ForEach(order, id: \.self) { key in
                    Label(names[key]?.0 ?? key, systemImage: names[key]?.1 ?? "circle")
                        .listRowBackground(Color.primary.opacity(0.06))
                }
                .onMove { source, destination in
                    var list = order
                    list.move(fromOffsets: source, toOffset: destination)
                    manager.config.expandedOrder = list
                }
            } header: {
                Text("Drag to reorder, top to bottom")
            } footer: {
                Text("Rows you've turned off stay hidden wherever you put them.")
            }

            Section {
                Button("Reset to the original order") {
                    manager.config.expandedOrder = []
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(ThemeBackground())
        .navigationTitle("Section order")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Optional colors (empty means "follow my accent")

struct OptionalColorField: View {
    @EnvironmentObject var manager: IslandManager
    let title: String
    var icon: String? = nil
    @Binding var hex: String

    var body: some View {
        if hex.isEmpty {
            Button {
                hex = manager.config.keylineHex
            } label: {
                HStack(spacing: 10) {
                    if let icon {
                        IconBadge(systemName: icon, color: .orange)
                    }
                    Text(title).foregroundStyle(.primary)
                    Spacer()
                    Text("Follows accent").font(.footnote).foregroundStyle(.secondary)
                    Image(systemName: "plus.circle.fill").foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ColorField(title: title, icon: icon, hex: $hex)
                Button("Use my accent instead") { hex = "" }
                    .font(.footnote.weight(.semibold))
            }
        }
    }
}

// MARK: - Sounds

@MainActor
enum ChimePlayer {
    private static var player: AVAudioPlayer?

    static func play(_ name: String) {
        guard name != "default" else {
            AudioServicesPlaySystemSound(1007)
            return
        }
        guard let url = Bundle.main.url(forResource: "chime-" + name, withExtension: "wav") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}

struct SoundCard: View {
    @EnvironmentObject var manager: IslandManager

    private let sounds: [(String, String)] = [
        ("default", "Default"), ("soft", "Soft"), ("bell", "Bell"), ("pop", "Pop"), ("ding", "Ding")
    ]

    var body: some View {
        Card(title: "Pop-out sound", icon: "speaker.wave.2.fill", tint: .pink,
             footer: "Plays when the island pops out, if Play sound is on (Studio → Expanded → Pop-outs). Tap one to hear it.") {
            ForEach(sounds, id: \.0) { item in
                Button {
                    manager.settings.chimeName = item.0
                    ChimePlayer.play(item.0)
                } label: {
                    HStack {
                        Image(systemName: manager.settings.chimeName == item.0 ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(manager.settings.chimeName == item.0 ? Color.pink : Color.secondary)
                        Text(item.1)
                        Spacer()
                        Image(systemName: "play.fill").font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Quick launch

struct QuickLinksCard: View {
    @EnvironmentObject var manager: IslandManager

    private let known: [(String, String, String)] = [
        ("📸", "Instagram", "instagram://app"), ("🎧", "Spotify", "spotify://"), ("🎵", "Apple Music", "music://"),
        ("🗺️", "Maps", "maps://"), ("💬", "Messages", "sms:"), ("📞", "Phone", "tel:"),
        ("⚡️", "Shortcuts", "shortcuts://"), ("📝", "Notes", "mobilenotes://"), ("▶️", "YouTube", "youtube://"),
        ("👾", "Discord", "discord://")
    ]

    var body: some View {
        Card(title: "Quick launch", icon: "bolt.horizontal.fill", tint: .teal,
             footer: "Up to four buttons in the long-press view that open an app or link. Only apps that are installed will open.") {
            ForEach($manager.settings.quickLinks) { $item in
                HStack(spacing: 8) {
                    TextField("🔗", text: $item.emoji)
                        .frame(width: 52)
                        .multilineTextAlignment(.center)
                        .cardField()
                    TextField("instagram://", text: $item.url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .cardField()
                    Button {
                        manager.settings.quickLinks.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.red)
                }
            }
            if manager.settings.quickLinks.count < 4 {
                Menu {
                    ForEach(known, id: \.1) { entry in
                        Button(entry.0 + " " + entry.1) {
                            manager.settings.quickLinks.append(QuickLinkItem(emoji: entry.0, url: entry.2))
                        }
                    }
                    Button("Custom link") {
                        manager.settings.quickLinks.append(QuickLinkItem())
                    }
                } label: {
                    Label("Add a button", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
        }
    }
}

// MARK: - Accessibility

struct AccessibilityCard: View {
    @EnvironmentObject var manager: IslandManager

    var body: some View {
        Card(title: "Accessibility", icon: "accessibility", tint: .blue,
             footer: "Reduce motion freezes the step animations. High contrast forces a black Lock Screen card and turns off glow and backings.") {
            ToggleRow(title: "Reduce motion", icon: "figure.walk.motion", color: .teal,
                      isOn: $manager.settings.reduceMotion)
            RowDivider()
            ToggleRow(title: "High contrast", icon: "circle.lefthalf.filled", color: .gray,
                      isOn: $manager.settings.highContrast)
            RowDivider()
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Lock Screen text size")
                    Spacer()
                    Text("\(Int((manager.settings.textScale * 100).rounded()))%").foregroundStyle(.secondary)
                }
                GlowSlider(value: $manager.settings.textScale, in: 1...1.5, step: 0.1)
            }
        }
    }
}

// MARK: - Share a preset as an image

struct PresetShareCard: View {
    let name: String
    let state: IslandState
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [accent.opacity(0.9), accent.darker(0.35), Color.black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 22) {
                Spacer()
                IslandPreview(state: state)
                Text(name)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 20)
                Text("Made with Island Studio")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))
                Spacer()
            }
        }
        .frame(width: 360, height: 420)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }
}

struct PresetShareSheet: View {
    @EnvironmentObject var manager: IslandManager
    @Environment(\.dismiss) private var dismiss
    let preset: SavedPreset
    @State private var image: UIImage?

    private var card: PresetShareCard {
        PresetShareCard(name: preset.name,
                        state: manager.previewState(style: preset.style, at: Date()),
                        accent: preset.style.accentColor)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                card
                    .shadow(color: Color.black.opacity(0.35), radius: 16, y: 8)
                if let image {
                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview(preset.name, image: Image(uiImage: image))) {
                        Label("Share image", systemImage: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundStyle(Color.white)
                    }
                }
                WideButton(title: "Copy share code instead", icon: "doc.on.doc") {
                    manager.copyShareCode(preset)
                }
            }
            .padding(20)
            .frame(maxHeight: .infinity)
            .background(ThemeBackground())
            .navigationTitle("Share preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { render() }
        }
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .dark))
        renderer.scale = 3
        image = renderer.uiImage
    }
}
