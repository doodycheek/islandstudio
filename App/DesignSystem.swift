import SwiftUI

// MARK: - Theme

enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case island, purple, blue, pink, orange, green, mint, red, mono

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .island: return Color(red: 0.0, green: 0.9, blue: 1.0)
        case .purple: return Color(red: 0.58, green: 0.38, blue: 0.98)
        case .blue: return Color(red: 0.20, green: 0.52, blue: 1.00)
        case .pink: return Color(red: 1.00, green: 0.33, blue: 0.62)
        case .orange: return Color(red: 1.00, green: 0.58, blue: 0.16)
        case .green: return Color(red: 0.20, green: 0.80, blue: 0.42)
        case .mint: return Color(red: 0.25, green: 0.85, blue: 0.80)
        case .red: return Color(red: 1.00, green: 0.27, blue: 0.27)
        case .mono: return Color(white: 0.55)
        }
    }
}

enum AppTab: String {
    case studio, presets, settings
}

private struct ThemeAccentKey: EnvironmentKey {
    static let defaultValue: Color = AccentChoice.purple.color
}

extension EnvironmentValues {
    /// The app's chosen accent color, set once at the root.
    var themeAccent: Color {
        get { self[ThemeAccentKey.self] }
        set { self[ThemeAccentKey.self] = newValue }
    }
}

/// The canvas behind every screen: a deep gradient with soft glowing color blobs.
struct ThemeBackground: View {
    @Environment(\.themeAccent) private var accent
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.top, theme.bottom], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill((theme.blobA ?? accent).opacity(theme.isLight ? 0.30 : 0.38))
                .frame(width: 420, height: 420)
                .blur(radius: 110)
                .offset(x: -150, y: -300)
            Circle()
                .fill((theme.blobB ?? accent).opacity(theme.isLight ? 0.22 : 0.26))
                .frame(width: 380, height: 380)
                .blur(radius: 120)
                .offset(x: 170, y: 320)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Gives a Form the app's themed background.
    func themedForm() -> some View {
        scrollContentBackground(.hidden)
            .background(ThemeBackground())
    }

    /// Text field look used inside cards.
    func cardField() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Building blocks

/// A glass card with a glowing icon header.
struct Card<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let footer: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let content: Content
    @Environment(\.appTheme) private var theme

    init(title: String, icon: String, tint: Color, footer: String? = nil,
         actionTitle: String? = nil, action: (() -> Void)? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.footer = footer
        self.actionTitle = actionTitle
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                IconBadge(systemName: icon, color: tint, size: 30)
                Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(tint.opacity(0.22)))
                            .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            content
            if let footer {
                Text(footer)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlassBackground(radius: 28, theme: theme, tint: tint))
    }
}

/// A Settings-app style colored icon square.
struct IconBadge: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.65)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
            .shadow(color: color.opacity(0.45), radius: 6, y: 2)
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                IconBadge(systemName: icon, color: color)
                Text(title).font(.system(size: 16, weight: .medium, design: .rounded))
            }
        }
        .toggleStyle(GlowToggleStyle())
    }
}

/// Label for a row that opens another screen.
struct NavRowLabel: View {
    let title: String
    let icon: String
    let color: Color
    var value: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            IconBadge(systemName: icon, color: color)
            Text(title).foregroundStyle(.primary)
            Spacer()
            if let value {
                Text(value).foregroundStyle(.secondary).lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

struct RowDivider: View {
    var body: some View {
        Divider().padding(.leading, 38)
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.themeAccent) private var accent

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(selected
                              ? AnyShapeStyle(LinearGradient(colors: [accent.opacity(0.85), accent],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Color.primary.opacity(0.08)))
                        .shadow(color: selected ? accent.opacity(0.5) : Color.clear, radius: 6)
                )
                .overlay(Capsule().strokeBorder(Color.primary.opacity(selected ? 0 : 0.1), lineWidth: 1))
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

/// Small capsule action button.
struct PillButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Wide rounded action button used in pairs.
struct WideButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Horizontal picker of SF Symbols ("" = none).
struct IconStrip: View {
    @Binding var symbol: String
    @Environment(\.themeAccent) private var accent
    @State private var showAll = false

    static let symbols = ["", "sparkles", "heart.fill", "star.fill", "bolt.fill", "flame.fill", "moon.stars.fill",
                          "music.note", "crown.fill", "leaf.fill", "sun.max.fill", "cloud.fill", "gamecontroller.fill",
                          "car.fill", "pawprint.fill", "headphones", "lock.fill", "bell.fill", "camera.fill", "gift.fill"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            strip
            HStack {
                Text(IconCatalog.title(for: symbol))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Browse all") { showAll = true }
                    .font(.caption.weight(.semibold))
            }
        }
        .sheet(isPresented: $showAll) {
            IconPickerView(symbol: $symbol, allowNone: true)
        }
    }

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.symbols, id: \.self) { name in
                    Button {
                        symbol = name
                    } label: {
                        Image(systemName: name.isEmpty ? "nosign" : name)
                            .font(.body)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(symbol == name ? accent.opacity(0.25) : Color(.tertiarySystemFill)))
                            .foregroundStyle(symbol == name ? accent : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Multi-select chips for the Lock Screen / expanded info chips.
struct ChipPicker: View {
    @Binding var kinds: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChipKind.allCases) { kind in
                    FilterChip(title: kind.label, selected: kinds.contains(kind.rawValue)) {
                        if let index = kinds.firstIndex(of: kind.rawValue) {
                            kinds.remove(at: index)
                        } else {
                            kinds.append(kind.rawValue)
                        }
                    }
                }
            }
        }
    }
}

/// Big full-width Start/Stop button.
struct StartStopButton: View {
    @EnvironmentObject var manager: IslandManager
    @Environment(\.themeAccent) private var accent

    var body: some View {
        Button {
            Task {
                if manager.isRunning {
                    await manager.stop()
                } else {
                    await manager.start()
                }
            }
        } label: {
            Label(manager.isRunning ? "Stop island" : "Start island",
                  systemImage: manager.isRunning ? "stop.fill" : "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(manager.isRunning ? Color.red.gradient : accent.gradient)
                )
        }
        .buttonStyle(.plain)
    }
}
