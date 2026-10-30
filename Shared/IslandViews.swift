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

    var body: some View {
        let inner = SlotView(slot: slot, state: state, size: size)
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

    var body: some View {
        switch state.lockLayout {
        case .classic: classic
        case .compact: compact
        case .hero: hero
        }
    }

    private var classic: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SlotBadge(slot: state.left, state: state, accent: accent, diameter: 46)
                titles(titleSize: 17, subtitleSize: 13)
                Spacer(minLength: 4)
                SlotBadge(slot: state.right, state: state, accent: accent, diameter: 46)
            }
            if state.lockChips { InfoChipRow(state: state) }
            if state.lockAccent { AccentBar(state: state) }
        }
        .padding(16)
        .foregroundStyle(.white)
    }

    private var compact: some View {
        HStack(spacing: 10) {
            SlotBadge(slot: state.left, state: state, accent: accent, diameter: 36)
            Text(state.lockTitleText)
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
            if state.lockChips { InfoChipRow(state: state) }
            if state.lockAccent { AccentBar(state: state) }
        }
        .padding(18)
        .foregroundStyle(.white)
    }

    private func titles(titleSize: CGFloat, subtitleSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(state.lockTitleText)
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
    }
}

/// Wraps a slot for the Lock Screen: a round badge for icons, a pill for text.
struct SlotBadge: View {
    let slot: SlotConfig
    let state: IslandState
    let accent: Color
    var diameter: CGFloat = 46

    var body: some View {
        if slot.content == .empty {
            EmptyView()
        } else if slot.content.isIconLike {
            SlotView(slot: slot, state: state, size: diameter * 0.56)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(accent.opacity(0.18)))
                .overlay(Circle().strokeBorder(accent.opacity(0.35), lineWidth: 1))
        } else {
            SlotView(slot: slot, state: state, size: diameter * 0.48)
                .padding(.horizontal, diameter * 0.26)
                .frame(height: diameter * 0.87)
                .background(Capsule().fill(Color.white.opacity(0.10)))
        }
    }
}

struct AccentBar: View {
    let state: IslandState

    private var cycleRange: ClosedRange<Date> {
        state.cycleStart...max(state.cycleEnd, state.cycleStart.addingTimeInterval(1))
    }

    var body: some View {
        ProgressView(timerInterval: cycleRange, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(state.accentColor)
    }
}

struct InfoChipRow: View {
    let state: IslandState

    var body: some View {
        HStack(spacing: 6) {
            if state.battery >= 0 {
                BatteryChip(level: state.battery, charging: state.charging)
            }
            if let temp = state.weatherTemp {
                InfoChip(icon: state.weatherSymbol.isEmpty ? "cloud.sun.fill" : state.weatherSymbol,
                         text: "\(temp)°", multicolor: true)
            }
            if state.steps >= 0 {
                InfoChip(icon: "figure.walk", text: state.steps.formatted())
            }
            InfoChip(icon: "calendar", text: state.now.formatted(.dateTime.weekday(.abbreviated).day()))
            Spacer(minLength: 0)
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

    var body: some View {
        Group {
            if state.bannerText.isEmpty {
                Text(state.expandedTitle)
                    .font(.headline)
            } else {
                Text(state.bannerText)
                    .font(.title3.weight(.bold))
            }
        }
        .fontDesign(state.design)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

struct ExpandedBottom: View {
    let state: IslandState

    var body: some View {
        VStack(spacing: 8) {
            if !state.expandedSubtitle.isEmpty {
                Text(state.expandedSubtitle)
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
            if state.showTimerButton {
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
            if state.showButtons {
                HStack(spacing: 28) {
                    Button(intent: PreviousPresetIntent()) {
                        Image(systemName: "chevron.left.circle.fill")
                    }
                    Button(intent: TogglePauseIntent()) {
                        Image(systemName: state.paused ? "play.circle.fill" : "pause.circle.fill")
                    }
                    Button(intent: NextPresetIntent()) {
                        Image(systemName: "chevron.right.circle.fill")
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
