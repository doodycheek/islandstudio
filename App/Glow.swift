import SwiftUI

// MARK: - App theme packs

/// The look of the whole app. Separate from your island's accent color.
enum AppTheme: String, CaseIterable, Identifiable {
    case midnight, aurora, neon, paper, terminal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .midnight: return "Midnight"
        case .aurora: return "Aurora"
        case .neon: return "Neon"
        case .paper: return "Paper"
        case .terminal: return "Terminal"
        }
    }

    var icon: String {
        switch self {
        case .midnight: return "moon.stars.fill"
        case .aurora: return "sparkles"
        case .neon: return "bolt.fill"
        case .paper: return "doc.text.fill"
        case .terminal: return "terminal.fill"
        }
    }

    var isLight: Bool { self == .paper }
    var scheme: ColorScheme { isLight ? .light : .dark }
    var design: Font.Design { self == .terminal ? .monospaced : .default }

    var top: Color {
        switch self {
        case .midnight: return Color(red: 0.09, green: 0.07, blue: 0.18)
        case .aurora: return Color(red: 0.02, green: 0.16, blue: 0.18)
        case .neon: return Color(red: 0.06, green: 0.0, blue: 0.12)
        case .paper: return Color(red: 0.98, green: 0.96, blue: 0.93)
        case .terminal: return Color(red: 0.0, green: 0.07, blue: 0.03)
        }
    }

    var bottom: Color {
        switch self {
        case .midnight: return Color(red: 0.02, green: 0.02, blue: 0.06)
        case .aurora: return Color(red: 0.03, green: 0.04, blue: 0.12)
        case .neon: return Color(red: 0.0, green: 0.0, blue: 0.03)
        case .paper: return Color(red: 0.93, green: 0.90, blue: 0.85)
        case .terminal: return Color(red: 0.0, green: 0.01, blue: 0.0)
        }
    }

    var cardFill: Color {
        switch self {
        case .midnight: return Color.white.opacity(0.06)
        case .aurora: return Color.white.opacity(0.07)
        case .neon: return Color.white.opacity(0.05)
        case .paper: return Color.white.opacity(0.78)
        case .terminal: return Color(red: 0.0, green: 0.2, blue: 0.08).opacity(0.35)
        }
    }

    var borderTop: Color {
        switch self {
        case .midnight: return Color.white.opacity(0.28)
        case .aurora: return Color(red: 0.4, green: 1.0, blue: 0.8).opacity(0.4)
        case .neon: return Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.55)
        case .paper: return Color.black.opacity(0.08)
        case .terminal: return Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.5)
        }
    }

    var borderBottom: Color {
        switch self {
        case .midnight: return Color.white.opacity(0.04)
        case .aurora: return Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.25)
        case .neon: return Color(red: 1.0, green: 0.1, blue: 0.7).opacity(0.4)
        case .paper: return Color.black.opacity(0.03)
        case .terminal: return Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.1)
        }
    }

    /// Theme glow colors. nil means "use the accent color".
    var blobA: Color? {
        switch self {
        case .aurora: return Color(red: 0.1, green: 0.9, blue: 0.6)
        case .neon: return Color(red: 1.0, green: 0.1, blue: 0.7)
        case .terminal: return Color(red: 0.1, green: 0.9, blue: 0.3)
        default: return nil
        }
    }

    var blobB: Color? {
        switch self {
        case .aurora: return Color(red: 0.55, green: 0.35, blue: 1.0)
        case .neon: return Color(red: 0.0, green: 0.85, blue: 1.0)
        case .terminal: return Color(red: 0.0, green: 0.5, blue: 0.2)
        default: return nil
        }
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .midnight
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - Glass surfaces

/// Frosted glass with a glowing edge, used behind cards and sections.
struct GlassBackground: View {
    let radius: CGFloat
    let theme: AppTheme
    var tint: Color = Color.clear

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(theme.cardFill)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(theme.isLight ? 0.10 : 0.16), Color.clear],
                                     startPoint: .topLeading, endPoint: .center))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [theme.borderTop, theme.borderBottom],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(theme.isLight ? 0.08 : 0.35), radius: 14, y: 6)
    }
}

/// Like a Form section, but as a glass card. Same call shape as Section.
struct GSection<Content: View>: View {
    let title: String?
    let header: AnyView?
    let footer: AnyView?
    let content: Content
    @Environment(\.appTheme) private var theme

    init(@ViewBuilder content: () -> Content) {
        self.title = nil
        self.header = nil
        self.footer = nil
        self.content = content()
    }

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.header = nil
        self.footer = nil
        self.content = content()
    }

    init<H: View>(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> H) {
        self.title = nil
        self.header = AnyView(header())
        self.footer = nil
        self.content = content()
    }

    init<F: View>(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> F) {
        self.title = nil
        self.header = nil
        self.footer = AnyView(footer())
        self.content = content()
    }

    init<H: View, F: View>(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> H,
                           @ViewBuilder footer: () -> F) {
        self.title = nil
        self.header = AnyView(header())
        self.footer = AnyView(footer())
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.system(size: 17, weight: .bold, design: .rounded))
            }
            if let header {
                header.font(.system(size: 17, weight: .bold, design: .rounded))
            }
            content
            if let footer {
                footer
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlassBackground(radius: 28, theme: theme))
    }
}

// MARK: - Custom controls

/// A toggle that glows when it's on.
struct GlowToggleStyle: ToggleStyle {
    @Environment(\.themeAccent) private var accent

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 8)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn
                          ? AnyShapeStyle(LinearGradient(colors: [accent.opacity(0.8), accent],
                                                         startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(Color.primary.opacity(0.16)))
                    .frame(width: 52, height: 30)
                    .shadow(color: configuration.isOn ? accent.opacity(0.55) : Color.clear, radius: 8)
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .padding(3)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: configuration.isOn)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            configuration.isOn.toggle()
        }
        .sensoryFeedback(.selection, trigger: configuration.isOn)
    }
}

/// A slider with a glowing track. Same call shape as Slider.
struct GlowSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    @Environment(\.themeAccent) private var accent

    init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 0) {
        _value = value
        self.range = range
        self.step = step
    }

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat(min(max((value - range.lowerBound) / span, 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 40)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 8)
                Capsule()
                    .fill(LinearGradient(colors: [accent.opacity(0.55), accent], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, (width - 24) * fraction + 12), height: 8)
                    .shadow(color: accent.opacity(0.55), radius: 6)
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: accent.opacity(0.7), radius: 6)
                    .offset(x: (width - 24) * fraction)
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let raw = Double(min(max((drag.location.x - 12) / (width - 24), 0), 1))
                        var next = range.lowerBound + raw * (range.upperBound - range.lowerBound)
                        if step > 0 {
                            next = ((next - range.lowerBound) / step).rounded() * step + range.lowerBound
                        }
                        value = min(max(next, range.lowerBound), range.upperBound)
                    }
            )
        }
        .frame(height: 28)
        .sensoryFeedback(.selection, trigger: value)
    }
}

/// A sliding-pill segmented control.
struct SegmentedPills<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]
    @Namespace private var pill
    @Environment(\.themeAccent) private var accent
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = selection == option.0
                Text(option.1)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.7))
                    .background {
                        if selected {
                            Capsule()
                                .fill(LinearGradient(colors: [accent.opacity(0.85), accent],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: accent.opacity(0.5), radius: 6)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selection = option.0
                        }
                    }
            }
        }
        .padding(4)
        .background(Capsule().fill(theme.isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.08)))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Floating tab bar

struct FloatingTabBar: View {
    @Binding var selection: String
    @Environment(\.themeAccent) private var accent
    @Namespace private var tabPill

    private let items: [(String, String, String)] = [
        ("studio", "wand.and.stars", "Studio"),
        ("presets", "square.grid.2x2.fill", "Presets"),
        ("settings", "gearshape.fill", "Settings")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.0) { item in
                let selected = selection == item.0
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        selection = item.0
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: item.1)
                            .font(.system(size: 17, weight: .semibold))
                        if selected {
                            Text(item.2)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                    .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.65))
                    .padding(.horizontal, selected ? 18 : 15)
                    .padding(.vertical, 12)
                    .background {
                        if selected {
                            Capsule()
                                .fill(LinearGradient(colors: [accent.opacity(0.85), accent],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: accent.opacity(0.55), radius: 10)
                                .matchedGeometryEffect(id: "tab", in: tabPill)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 18, y: 8)
        .padding(.bottom, 8)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Loading screen

/// The animated screen shown when the app opens: the island stretches out and your heart beats.
struct SplashView: View {
    @Environment(\.themeAccent) private var accent
    @State private var expanded = false
    @State private var beat = false
    @State private var showText = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.38), Color.clear], center: .center, startRadius: 10, endRadius: 380)
                .ignoresSafeArea()
                .opacity(expanded ? 1 : 0)
            VStack(spacing: 26) {
                ZStack {
                    Capsule()
                        .fill(Color.black)
                        .overlay(Capsule().strokeBorder(LinearGradient(colors: [accent, accent.opacity(0.15)],
                                                                       startPoint: .leading, endPoint: .trailing),
                                                        lineWidth: 1.5))
                        .shadow(color: accent.opacity(0.7), radius: expanded ? 30 : 6)
                        .frame(width: expanded ? 240 : 46, height: 46)
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(LinearGradient(colors: [accent, Color.pink],
                                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                            .scaleEffect(beat ? 1.22 : 0.9)
                        Spacer()
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .padding(.horizontal, 24)
                    .frame(width: 240)
                    .opacity(expanded ? 1 : 0)
                }
                Text("Island Studio")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .opacity(showText ? 1 : 0)
                    .offset(y: showText ? 0 : 14)
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 150, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(accent)
                            .frame(width: 54, height: 4)
                            .offset(x: shimmer ? 96 : 0)
                    }
                    .opacity(showText ? 1 : 0)
            }
        }
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { expanded = true }
            withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) { beat = true }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeOut(duration: 0.5)) { showText = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { shimmer = true }
        }
    }
}
