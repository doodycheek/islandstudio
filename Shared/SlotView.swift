import SwiftUI
import UIKit

/// Renders one slot of the island. Shared by the widget (real island) and the app (preview).
struct SlotView: View {
    let slot: SlotConfig
    let state: IslandState
    var size: CGFloat = 20

    private var color: Color { Color(hex: slot.colorHex) }

    private func symbolOr(_ fallback: String) -> String {
        slot.symbol.trimmingCharacters(in: .whitespaces).isEmpty ? fallback : slot.symbol
    }

    private var cycleRange: ClosedRange<Date> {
        state.cycleStart...max(state.cycleEnd, state.cycleStart.addingTimeInterval(1))
    }

    private var batterySymbol: String {
        if state.charging { return "battery.100.bolt" }
        let b = state.battery
        if b < 0 || b >= 88 { return "battery.100" }
        if b >= 63 { return "battery.75" }
        if b >= 38 { return "battery.50" }
        if b >= 13 { return "battery.25" }
        return "battery.0"
    }

    var body: some View {
        content
            .fontDesign(state.design)
            .fontWeight(state.bold ? .bold : .regular)
    }

    @ViewBuilder private var content: some View {
        switch slot.content {
        case .empty:
            EmptyView()

        case .text:
            Text(slot.text)
                .font(.system(size: size * 0.75))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

        case .emoji:
            Text(slot.text)
                .font(.system(size: size * 0.85))
                .lineLimit(1)

        case .symbol:
            Image(systemName: symbolOr("star.fill"))
                .font(.system(size: size * 0.8))
                .foregroundStyle(color)

        case .image:
            if let data = state.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "photo")
                    .font(.system(size: size * 0.8))
                    .foregroundStyle(color)
            }

        case .clock:
            Text(state.now, format: .dateTime.hour().minute())
                .font(.system(size: size * 0.7))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)

        case .liveClock:
            // Counting up from midnight = live time of day with seconds, no updates needed.
            Text(Calendar.current.startOfDay(for: Date()), style: .timer)
                .font(.system(size: size * 0.65))
                .monospacedDigit()
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .frame(width: size * 3.4)

        case .date:
            Text(state.now, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: size * 0.7))
                .foregroundStyle(color)
                .lineLimit(1)

        case .battery:
            HStack(spacing: 2) {
                Image(systemName: batterySymbol)
                if state.battery >= 0 { Text("\(state.battery)%") }
            }
            .font(.system(size: size * 0.6))
            .foregroundStyle(color)

        case .ring:
            ProgressView(timerInterval: cycleRange, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(color)
            .frame(width: size, height: size)

        case .bar:
            ProgressView(timerInterval: cycleRange, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(color)
            .frame(width: size * 2.5)

        case .timer:
            Text(state.sessionStart, style: .timer)
                .font(.system(size: size * 0.65))
                .monospacedDigit()
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .frame(width: size * 2.6)

        case .pulse:
            Image(systemName: symbolOr("circle.fill"))
                .font(.system(size: size * 0.8))
                .foregroundStyle(color)
                .scaleEffect(state.frame % 2 == 0 ? 1.0 : 0.6)
                .opacity(state.frame % 2 == 0 ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.8), value: state.frame)

        case .equalizer:
            EqualizerView(frame: state.frame, color: color, size: size)

        case .spin:
            Image(systemName: symbolOr("arrow.triangle.2.circlepath"))
                .font(.system(size: size * 0.8))
                .foregroundStyle(color)
                .rotationEffect(.degrees(Double(state.frame) * 90))
                .animation(.easeInOut(duration: 0.8), value: state.frame)

        case .rainbow:
            Image(systemName: symbolOr("sparkles"))
                .font(.system(size: size * 0.8))
                .foregroundStyle(Color(hue: Double(state.frame % 12) / 12.0, saturation: 0.9, brightness: 1.0))
                .animation(.linear(duration: 0.8), value: state.frame)
        }
    }
}

struct EqualizerView: View {
    let frame: Int
    let color: Color
    let size: CGFloat

    static func height(frame: Int, index: Int) -> CGFloat {
        let seed = abs(frame &* 31 &+ index &* 17) % 7
        return 0.3 + CGFloat(seed) / 10.0
    }

    var body: some View {
        HStack(alignment: .center, spacing: size * 0.12) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.14, height: size * Self.height(frame: frame, index: i))
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.6), value: frame)
    }
}
