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
    case purple, blue, pink, orange, green, mint, red, mono

    var id: String { rawValue }

    var color: Color {
        switch self {
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

/// Soft accent-tinted background behind every screen.
struct ThemeBackground: View {
    @Environment(\.themeAccent) private var accent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(colors: [accent.opacity(scheme == .dark ? 0.32 : 0.20), Color.clear],
                           startPoint: .top, endPoint: .center)
            RadialGradient(colors: [accent.opacity(scheme == .dark ? 0.22 : 0.12), Color.clear],
                           center: .bottomTrailing, startRadius: 10, endRadius: 460)
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
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.tertiarySystemFill)))
    }
}

// MARK: - Building blocks

/// A glassy rounded card with a colored icon header.
struct Card<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let footer: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let content: Content

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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                IconBadge(systemName: icon, color: tint, size: 24)
                Text(title).font(.headline)
                Spacer()
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.subheadline.weight(.semibold))
                }
            }
            content
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
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
            .background(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(color.gradient))
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
                Text(title)
            }
        }
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
                .background(Capsule().fill(selected ? AnyShapeStyle(accent) : AnyShapeStyle(Material.regularMaterial)))
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
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
