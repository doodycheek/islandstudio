import AppIntents
import SwiftUI

// Views shared by the widget (real Lock Screen / island) and the app (live previews).

// MARK: - Lock Screen

struct LockScreenView: View {
    let state: IslandState

    private var accent: Color { state.accentColor }

    private var cycleRange: ClosedRange<Date> {
        state.cycleStart...max(state.cycleEnd, state.cycleStart.addingTimeInterval(1))
    }

    private var title: String {
        state.bannerText.isEmpty ? state.expandedTitle : state.bannerText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SlotBadge(slot: state.left, state: state, accent: accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                    if !state.expandedSubtitle.isEmpty {
                        Text(state.expandedSubtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .fontDesign(state.design)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                SlotBadge(slot: state.right, state: state, accent: accent)
            }

            if state.lockChips {
                HStack(spacing: 6) {
                    if state.battery >= 0 {
                        InfoChip(icon: state.charging ? "battery.100.bolt" : "battery.75", text: "\(state.battery)%")
                    }
                    if let temp = state.weatherTemp {
                        InfoChip(icon: state.weatherSymbol.isEmpty ? "cloud.sun.fill" : state.weatherSymbol, text: "\(temp)°")
                    }
                    if state.steps >= 0 {
                        InfoChip(icon: "figure.walk", text: state.steps.formatted())
                    }
                    InfoChip(icon: "calendar", text: state.now.formatted(.dateTime.weekday(.abbreviated).day()))
                    Spacer(minLength: 0)
                }
            }

            if state.lockAccent {
                ProgressView(timerInterval: cycleRange, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(accent)
            }
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

/// Wraps a slot for the Lock Screen: a round badge for icons, a pill for text.
struct SlotBadge: View {
    let slot: SlotConfig
    let state: IslandState
    let accent: Color

    var body: some View {
        if slot.content == .empty {
            EmptyView()
        } else if slot.content.isIconLike {
            SlotView(slot: slot, state: state, size: 26)
                .frame(width: 46, height: 46)
                .background(Circle().fill(accent.opacity(0.18)))
                .overlay(Circle().strokeBorder(accent.opacity(0.35), lineWidth: 1))
        } else {
            SlotView(slot: slot, state: state, size: 22)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Capsule().fill(Color.white.opacity(0.10)))
        }
    }
}

struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.12)))
    }
}

// MARK: - Expanded island (long-press)

/// Title in the long-press view. Shows the pop-out banner (hour or charging) when one is active.
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
    }
}
