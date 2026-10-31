import AppIntents
import SwiftUI

// Views shared by the widget (real Lock Screen / island) and the app (live previews).

// MARK: - Island background

extension IslandState {
    /// Fill for the colored backing behind icons and text.
    func backdropStyle(strength: Double = 1) -> AnyShapeStyle {
        switch islandBg {
        case .none:
            return AnyShapeStyle(Color.clear)
        case .tint:
            return AnyShapeStyle(accentColor.opacity(0.32 * strength))
        case .gradient:
            return AnyShapeStyle(LinearGradient(
                colors: [accentColor.opacity(0.7 * strength), accentColor.hueShifted(0.14).opacity(0.7 * strength)],
                startPoint: .leading, endPoint: .trailing))
        }
    }
}

/// A compact-island slot with the optional colored backing.
struct CompactSlot: View {
    let slot: SlotConfig
    let state: IslandState
    var size: CGFloat = 20
    var minimal = false
    @Environment(\.isLuminanceReduced) private var dimmed

    private var showsRing: Bool { minimal && state.minimalRing }

    private var ringColor: Color {
        dimmed ? Color.white.opacity(0.5) : state.accentColor.opacity(0.65)
    }

    var body: some View {
        let inner = SlotView(slot: slot, state: state, size: size)
        Group {
            if state.islandBg == .none || slot.content == .empty {
                inner
            } else if minimal {
                inner
                    .padding(4)
                    .background(Circle().fill(state.backdropStyle()))
            } else {
                inner
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(state.backdropStyle()))
            }
        }
        .frame(maxWidth: showsRing ? CGFloat.infinity : nil, maxHeight: showsRing ? CGFloat.infinity : nil)
        .overlay {
            if showsRing {
                Circle()
                    .strokeBorder(ringColor, lineWidth: 1.5)
                    .shadow(color: state.accentColor.opacity(dimmed ? 0 : 0.7), radius: state.glow ? 5 : 3)
            }
        }
    }
}

/// Rounded colored panel behind a region of the long-press view.
struct IslandPanel: ViewModifier {
    let state: IslandState

    func body(content: Content) -> some View {
        if state.islandBg == .none {
            content
        } else {
            content
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(state.backdropStyle(strength: 0.8)))
        }
    }
}

extension View {
    func islandPanel(_ state: IslandState) -> some View {
        modifier(IslandPanel(state: state))
    }
}

// MARK: - Lock Screen

struct LockScreenView: View {
    let state: IslandState

    private var accent: Color { state.accentColor }

    private var titleColor: Color {
        state.lockTitleHex.isEmpty ? Color.white : Color(hex: state.lockTitleHex)
    }

    /// True on the Always-On Display, where iOS dims the screen and drops fine details.
    @Environment(\.isLuminanceReduced) private var dimmed

    private var titleAlignment: HorizontalAlignment {
        state.lockAlign == "center" ? .center : .leading
    }

    private var showGraph: Bool {
        !state.graphKind.isEmpty && state.spark.count > 1
    }

    var body: some View {
        Group {
            if dimmed {
                aod
            } else {
                switch state.lockLayout {
                case .classic: classic
                case .compact: compact
                case .hero: hero
                case .clock: bigClock
                }
            }
        }
        .background {
            if !dimmed, let colors = state.lockGradientColors {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            if !dimmed && state.lockStyle == .aurora {
                AuroraBackground(state: state)
            }
        }
    }

    /// Always-On Display: big, bright and simple, with plain digits instead of timers.
    private var aod: some View {
        HStack(spacing: 12) {
            SlotView(slot: state.left, state: state, size: 30, decorated: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.lockTitleText)
                    .font(.system(size: 18, weight: .bold))
                Text(ClockFormat.string(state.now, seconds: false, hour12: state.hour12))
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
            }
            .lineLimit(1)
            Spacer(minLength: 4)
            SlotView(slot: state.right, state: state, size: 30, decorated: false)
        }
        .padding(16)
        .foregroundStyle(Color.white)
    }

    private var bigClock: some View {
        VStack(spacing: 6) {
            HStack {
                SlotBadge(slot: state.left, state: state, accent: accent, diameter: 36)
                Spacer()
                SlotBadge(slot: state.right, state: state, accent: accent, diameter: 36)
            }
            Text(ClockFormat.string(state.now, seconds: false, hour12: state.hour12))
                .font(.system(size: 54, weight: .bold))
                .fontDesign(state.design)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !state.lockTitleText.isEmpty {
                Text(state.lockTitleText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
            }
            if showGraph { SparklineView(values: state.spark, color: accent).frame(height: 28) }
            if state.lockChips { InfoChipRow(state: state) }
            if state.lockAccent { AccentBar(state: state) }
        }
        .padding(16)
        .foregroundStyle(.white)
    }

    private var classic: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SlotBadge(slot: state.left, state: state, accent: accent, diameter: 46)
                titles(titleSize: 17, subtitleSize: 13)
                Spacer(minLength: 4)
                SlotBadge(slot: state.right, state: state, accent: accent, diameter: 46)
            }
            if showGraph { SparklineView(values: state.spark, color: accent).frame(height: 28) }
            if state.lockChips { InfoChipRow(state: state) }
            if state.lockAccent { AccentBar(state: state) }
        }
        .padding(16)
        .foregroundStyle(.white)
    }

    private var compact: some View {
        HStack(spacing: 10) {
            SlotBadge(slot: state.left, state: state, accent: accent, diameter: 36)
            HStack(spacing: 6) {
                if !state.lockIcon.isEmpty {
                    Image(systemName: state.lockIcon).foregroundStyle(accent)
                }
                Text(state.lockTitleText)
                    .foregroundStyle(titleColor)
            }
            .font(.system(size: 15, weight: .semibold))
            .fontDesign(state.design)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            SlotBadge(slot: state.right, state: state, accent: accent, diameter: 36)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(.white)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                SlotBadge(slot: state.left, state: state, accent: accent, diameter: 56)
                Spacer()
                SlotBadge(slot: state.right, state: state, accent: accent, diameter: 56)
            }
            titles(titleSize: 24, subtitleSize: 14)
            if showGraph { SparklineView(values: state.spark, color: accent).frame(height: 32) }
            if state.lockChips { InfoChipRow(state: state) }
            if state.lockAccent { AccentBar(state: state) }
        }
        .padding(18)
        .foregroundStyle(.white)
    }

    private func titles(titleSize: CGFloat, subtitleSize: CGFloat) -> some View {
        VStack(alignment: titleAlignment, spacing: 2) {
            HStack(spacing: 6) {
                if !state.lockIcon.isEmpty {
                    Image(systemName: state.lockIcon)
                        .foregroundStyle(accent)
                }
                Text(state.lockTitleText)
                    .foregroundStyle(titleColor)
            }
            .font(.system(size: titleSize, weight: .bold))
            if !state.lockSubtitleText.isEmpty {
                Text(state.lockSubtitleText)
                    .font(.system(size: subtitleSize))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .fontDesign(state.design)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: state.lockAlign == "center" ? CGFloat.infinity : nil)
    }
}

/// Wraps a slot for the Lock Screen: a badge for icons, a pill for text.
struct SlotBadge: View {
    let slot: SlotConfig
    let state: IslandState
    let accent: Color
    var diameter: CGFloat = 46

    var body: some View {
        if slot.content == .empty {
            EmptyView()
        } else if slot.content.isIconLike {
            SlotView(slot: slot, state: state, size: diameter * 0.56, decorated: false)
                .frame(width: diameter, height: diameter)
                .background { badgeBackground }
        } else {
            SlotView(slot: slot, state: state, size: diameter * 0.48, decorated: false)
                .padding(.horizontal, diameter * 0.26)
                .frame(height: diameter * 0.87)
                .background {
                    if state.badgeStyle != .none {
                        Capsule().fill(Color.white.opacity(0.10))
                    }
                }
        }
    }

    @ViewBuilder private var badgeBackground: some View {
        switch state.badgeStyle {
        case .circle:
            Circle()
                .fill(accent.opacity(0.18))
                .overlay(Circle().strokeBorder(accent.opacity(0.35), lineWidth: 1))
        case .squircle:
            RoundedRectangle(cornerRadius: diameter * 0.3, style: .continuous)
                .fill(accent.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: diameter * 0.3, style: .continuous)
                    .strokeBorder(accent.opacity(0.35), lineWidth: 1))
        case .none:
            EmptyView()
        }
    }
}

/// Progress bar: loops, fills through the day, shows battery, or counter progress.
struct AccentBar: View {
    let state: IslandState

    private var cycleRange: ClosedRange<Date> {
        state.cycleStart...max(state.cycleEnd, state.cycleStart.addingTimeInterval(1))
    }

    private var dayRange: ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: state.now)
        return start...start.addingTimeInterval(86_400)
    }

    private var barColor: Color {
        state.lockBarStyle == .battery
            ? BatteryGlyph.autoColor(level: state.battery, charging: state.charging, normal: state.accentColor)
            : state.accentColor
    }

    var body: some View {
        Group {
            switch state.lockBarStyle {
            case .loop:
                ProgressView(timerInterval: cycleRange, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            case .day:
                ProgressView(timerInterval: dayRange, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            case .battery:
                ProgressView(value: Double(max(state.battery, 0)) / 100)
            case .counter:
                ProgressView(value: state.counterGoal > 0
                             ? min(1, Double(state.counter) / Double(state.counterGoal)) : 0)
            }
        }
        .progressViewStyle(.linear)
        .tint(barColor)
    }
}

/// The chips you picked, in the order you picked them. Chips without data yet are skipped.
struct InfoChipRow: View {
    let state: IslandState

    private var countdownText: String {
        let remaining = state.countdownTarget.timeIntervalSince(state.now)
        if remaining <= 0 { return "Now" }
        let total = Int(remaining)
        if total >= 86_400 { return "\(total / 86_400)d" }
        return "\(total / 3600)h \((total % 3600) / 60)m"
    }

    private var focusText: String {
        let minutes = max(0, Int(ceil(state.pomoEnd.timeIntervalSince(state.now) / 60)))
        return (state.pomoPhase == "break" ? "☕ " : "🍅 ") + "\(minutes)m"
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(state.chipKinds, id: \.self) { raw in
                if let kind = ChipKind(rawValue: raw) {
                    chip(kind)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func chip(_ kind: ChipKind) -> some View {
        switch kind {
        case .battery:
            if state.battery >= 0 {
                BatteryChip(level: state.battery, charging: state.charging)
            }
        case .weather:
            if let temp = state.weatherTemp {
                InfoChip(icon: state.weatherSymbol.isEmpty ? "cloud.sun.fill" : state.weatherSymbol,
                         text: "\(temp)°", multicolor: true)
            }
        case .steps:
            if state.steps >= 0 {
                InfoChip(icon: "figure.walk", text: state.steps.formatted())
            }
        case .date:
            InfoChip(icon: "calendar", text: state.now.formatted(.dateTime.weekday(.abbreviated).day()))
        case .moon:
            let phase = MoonPhase.info(for: state.now)
            InfoChip(icon: phase.symbol, text: "\(phase.percent)%")
        case .counter:
            InfoChip(icon: "plus.circle.fill",
                     text: state.counterGoal > 0 ? "\(state.counter)/\(state.counterGoal)" : "\(state.counter)")
        case .crypto:
            if state.cryptoPrice != nil {
                InfoChip(icon: "bitcoinsign.circle.fill",
                         text: "\(state.cryptoSymbol) \(CryptoFormat.price(state.cryptoPrice))")
            }
        case .countdown:
            InfoChip(icon: "hourglass", text: countdownText)
        case .focus:
            if !state.pomoPhase.isEmpty {
                InfoChip(icon: "timer", text: focusText)
            }
        case .nextEvent:
            if !state.nextEventTitle.isEmpty {
                InfoChip(icon: "calendar", text: state.nextEventLine)
            }
        case .uv:
            if let uv = state.uv {
                InfoChip(icon: "sun.max.fill", text: "UV \(Int(uv.rounded()))", multicolor: true)
            }
        case .rain:
            if let chance = state.rainChance {
                InfoChip(icon: "drop.fill", text: "\(chance)%")
            }
        case .wind:
            if let speed = state.wind {
                InfoChip(icon: "wind", text: "\(speed)")
            }
        case .aqi:
            if let value = state.aqi {
                InfoChip(icon: "leaf.fill", text: "AQI \(value)")
            }
        case .network:
            InfoChip(icon: state.netType == "wifi" ? "wifi" : (state.netType == "cell" ? "antenna.radiowaves.left.and.right" : "wifi.slash"),
                     text: state.netType == "wifi" ? "Wi-Fi" : (state.netType == "cell" ? "Cellular" : "Offline"))
        case .storage:
            if state.storageGB >= 0 {
                InfoChip(icon: "internaldrive.fill", text: "\(state.storageGB) GB")
            }
        case .streak:
            if state.streak > 0 {
                InfoChip(icon: "flame.fill", text: "\(state.streak)")
            }
        }
    }
}

struct InfoChip: View {
    let icon: String
    let text: String
    var multicolor = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .symbolRenderingMode(multicolor ? SymbolRenderingMode.multicolor : SymbolRenderingMode.monochrome)
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.12)))
    }
}

/// Battery chip with the real level and color: green charging, orange getting low, red low.
struct BatteryChip: View {
    let level: Int
    let charging: Bool

    var body: some View {
        let color = BatteryGlyph.autoColor(level: level, charging: charging, normal: Color.white)
        HStack(spacing: 5) {
            BatteryGlyph(level: level, charging: charging, color: color, size: 17)
            Text("\(level)%")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(color)
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.12)))
    }
}

// MARK: - Expanded island (long-press)

/// Title in the long-press view. Shows the pop-out banner (hour, charging, alerts) when one is active.
struct ExpandedTitle: View {
    let state: IslandState

    private var titleFont: Font {
        if !state.bannerText.isEmpty { return .title3.weight(.bold) }
        switch state.expandedLayout {
        case .standard: return .headline
        case .centered: return .title2.weight(.bold)
        case .big: return .subheadline.weight(.semibold)
        }
    }

    private var titleColor: Color {
        state.expandedTitleHex.isEmpty ? Color.white : Color(hex: state.expandedTitleHex)
    }

    var body: some View {
        HStack(spacing: 6) {
            if !state.expandedIcon.isEmpty && state.bannerText.isEmpty {
                Image(systemName: state.expandedIcon)
                    .foregroundStyle(state.accentColor)
            }
            Text(state.bannerText.isEmpty ? state.expandedTitleText : state.bannerText)
                .foregroundStyle(titleColor)
        }
        .font(titleFont)
        .fontDesign(state.design)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// One of the buttons you picked for the long-press view.
struct IslandButton: View {
    let kind: ButtonKind
    let state: IslandState

    private var icon: String {
        switch kind {
        case .pause: return state.paused ? "play.circle.fill" : "pause.circle.fill"
        case .musicPlayPause: return state.musicPlaying ? "pause.fill" : "play.fill"
        case .focus: return state.pomoPhase.isEmpty ? "timer" : "stop.circle.fill"
        default: return kind.icon
        }
    }

    var body: some View {
        switch kind {
        case .prev:
            Button(intent: PreviousPresetIntent()) { Image(systemName: icon) }
        case .next:
            Button(intent: NextPresetIntent()) { Image(systemName: icon) }
        case .pause:
            Button(intent: TogglePauseIntent()) { Image(systemName: icon) }
        case .counterPlus:
            Button(intent: CounterPlusIntent()) { Image(systemName: icon) }
        case .counterMinus:
            Button(intent: CounterMinusIntent()) { Image(systemName: icon) }
        case .focus:
            Button(intent: PomodoroToggleIntent()) { Image(systemName: icon) }
        case .musicPrevious:
            Button(intent: MusicPreviousIntent()) { Image(systemName: icon) }
        case .musicPlayPause:
            Button(intent: MusicPlayPauseIntent()) { Image(systemName: icon) }
        case .musicNext:
            Button(intent: MusicNextIntent()) { Image(systemName: icon) }
        case .surprise:
            Button(intent: SurpriseIntent()) { Image(systemName: icon) }
        }
    }
}

struct ExpandedBottom: View {
    let state: IslandState

    var body: some View {
        VStack(spacing: 8) {
            if !state.expandedSubtitleText.isEmpty {
                Text(state.expandedSubtitleText)
                    .font(.subheadline)
                    .fontDesign(state.design)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if state.expandedChips {
                InfoChipRow(state: state)
                    .foregroundStyle(.white)
            }
            if state.expandedBar {
                AccentBar(state: state)
                    .padding(.horizontal, 8)
            }
            if !state.graphKind.isEmpty && state.spark.count > 1 {
                SparklineView(values: state.spark, color: state.accentColor)
                    .frame(height: 26)
                    .padding(.horizontal, 8)
            }
            if !state.reactions.isEmpty {
                HStack(spacing: 14) {
                    ForEach(state.reactions, id: \.self) { emoji in
                        Button(intent: ReactIntent(emoji: emoji)) {
                            Text(emoji).font(.title2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            if state.showCounterButtons {
                HStack(spacing: 18) {
                    Button(intent: CounterMinusIntent()) {
                        Image(systemName: "minus.circle.fill")
                    }
                    Text(state.counterGoal > 0 ? "\(state.counter)/\(state.counterGoal)" : "\(state.counter)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Button(intent: CounterPlusIntent()) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .font(.title2)
                .buttonStyle(.plain)
                .foregroundStyle(state.accentColor)
            }
            if state.showTimerButton && !state.buttonKinds.contains(ButtonKind.focus.rawValue) {
                Button(intent: PomodoroToggleIntent()) {
                    Label(state.pomoPhase.isEmpty ? "Start focus" : "Stop timer",
                          systemImage: state.pomoPhase.isEmpty ? "play.fill" : "stop.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(state.accentColor.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
            if state.showButtons && state.buttonKinds.contains(where: { ButtonKind(rawValue: $0) != nil }) {
                HStack(spacing: 26) {
                    ForEach(state.buttonKinds, id: \.self) { raw in
                        if let kind = ButtonKind(rawValue: raw) {
                            IslandButton(kind: kind, state: state)
                        }
                    }
                }
                .font(.title2)
                .buttonStyle(.plain)
                .foregroundStyle(state.accentColor)
            }
        }
        .islandPanel(state)
    }
}

// MARK: - Mini graphs and aurora

/// A tiny line chart of recent values (battery or steps).
struct SparklineView: View {
    let values: [Int]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let low = Double(values.min() ?? 0)
            let high = max(Double(values.max() ?? 1), low + 1)
            let count = max(values.count - 1, 1)
            let points: [CGPoint] = values.enumerated().map { item in
                let x = geo.size.width * CGFloat(item.offset) / CGFloat(count)
                let y = geo.size.height * (1 - CGFloat((Double(item.element) - low) / (high - low)))
                return CGPoint(x: x, y: y)
            }
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                        path.addLine(to: CGPoint(x: first.x, y: geo.size.height))
                        path.closeSubpath()
                    }
                }
                .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// A slowly shifting color wash behind the Lock Screen card.
struct AuroraBackground: View {
    let state: IslandState

    var body: some View {
        let drift = Double(state.frame % 600) / 600 * 0.3
        LinearGradient(
            colors: [state.accentColor.darker(0.35),
                     state.accentColor.hueShifted(0.12 + drift).darker(0.32),
                     state.accentColor.hueShifted(0.32 - drift).darker(0.3)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .animation(.easeInOut(duration: 1), value: state.frame)
    }
}
