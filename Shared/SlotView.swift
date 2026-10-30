import SwiftUI
import UIKit

/// Renders one slot of the island. Shared by the widget (real island) and the app (preview).
struct SlotView: View {
    let slot: SlotConfig
    let state: IslandState
    var size: CGFloat = 20

    private var c1: Color { Color(hex: slot.colorHex) }
    private var c2: Color { Color(hex: slot.color2Hex) }
    private var evenFrame: Bool { state.frame % 2 == 0 }

    /// Fill for text and icons: solid, gradient, or alternating colors.
    private var paint: AnyShapeStyle {
        switch slot.colorMode {
        case .solid:
            return AnyShapeStyle(c1)
        case .gradient:
            return AnyShapeStyle(LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .cycle:
            return AnyShapeStyle(evenFrame ? c1 : c2)
        }
    }

    /// Progress views only take a plain color.
    private var tintColor: Color { (slot.colorMode == .cycle && !evenFrame) ? c2 : c1 }

    private var marqueeWidth: Int { size < 28 ? 8 : 10 }
    private var marqueeFont: CGFloat { min(size * 0.7, 16) }

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

    private var musicLine: String {
        if state.musicTitle.isEmpty { return "Not playing" }
        if state.musicArtist.isEmpty { return state.musicTitle }
        return "\(state.musicTitle) - \(state.musicArtist)"
    }

    /// Neon glow color: the slot's own color, or the accent for content without one.
    private var glowColor: Color {
        if slot.content == .rainbow {
            return Color(hue: Double(state.frame % 12) / 12.0, saturation: 0.9, brightness: 1.0)
        }
        return slot.content.usesColor ? tintColor : state.accentColor
    }

    var body: some View {
        content
            .fontDesign(state.design)
            .fontWeight(state.bold ? .bold : .regular)
            .shadow(color: state.glow ? glowColor.opacity(0.9) : Color.clear, radius: state.glow ? size * 0.25 : 0)
            .shadow(color: state.glow ? glowColor.opacity(0.5) : Color.clear, radius: state.glow ? size * 0.5 : 0)
            .animation(slot.colorMode == .cycle ? Animation.easeInOut(duration: 0.8) : nil, value: state.frame)
    }

    @ViewBuilder private var content: some View {
        switch slot.content {
        case .empty:
            EmptyView()

        case .text:
            Text(slot.text)
                .font(.system(size: size * 0.75))
                .foregroundStyle(paint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

        case .emoji:
            Text(slot.text)
                .font(.system(size: size * 0.85))
                .lineLimit(1)

        case .symbol:
            Image(systemName: symbolOr("star.fill"))
                .font(.system(size: size * 0.8))
                .foregroundStyle(paint)

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
                    .foregroundStyle(paint)
            }

        case .clock:
            Text(state.now, format: .dateTime.hour().minute())
                .font(.system(size: size * 0.7))
                .monospacedDigit()
                .foregroundStyle(paint)
                .lineLimit(1)

        case .liveClock:
            // Counting up from midnight = live time of day with seconds, no updates needed.
            Text(Calendar.current.startOfDay(for: Date()), style: .timer)
                .font(.system(size: size * 0.65))
                .monospacedDigit()
                .foregroundStyle(paint)
                .multilineTextAlignment(.center)
                .frame(width: size * 3.4)

        case .date:
            Text(state.now, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: size * 0.7))
                .foregroundStyle(paint)
                .lineLimit(1)

        case .battery:
            HStack(spacing: 2) {
                Image(systemName: batterySymbol)
                if state.battery >= 0 { Text("\(state.battery)%") }
            }
            .font(.system(size: size * 0.6))
            .foregroundStyle(paint)

        case .music:
            Text(Marquee.window(musicLine, frame: state.musicPlaying ? state.frame : 0, width: marqueeWidth))
                .font(.system(size: marqueeFont))
                .fontDesign(.monospaced)
                .foregroundStyle(paint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

        case .musicArt:
            if let data = state.musicArt, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.8))
                    .foregroundStyle(Color.pink)
            }

        case .steps:
            HStack(spacing: 2) {
                Image(systemName: "figure.walk")
                if state.steps >= 0 {
                    Text(state.steps, format: .number)
                } else {
                    Text("--")
                }
            }
            .font(.system(size: size * 0.6))
            .foregroundStyle(paint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .weather:
            HStack(spacing: 3) {
                Image(systemName: state.weatherSymbol.isEmpty ? "cloud.sun.fill" : state.weatherSymbol)
                Text(state.weatherTemp.map { "\($0)°" } ?? "--°")
            }
            .font(.system(size: size * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .countdown:
            CountdownLabel(prefix: slot.text, target: state.countdownTarget, paint: paint, size: size)

        case .ring:
            ProgressView(timerInterval: cycleRange, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(tintColor)
            .frame(width: size, height: size)

        case .bar:
            ProgressView(timerInterval: cycleRange, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(tintColor)
            .frame(width: size * 2.5)

        case .timer:
            Text(state.sessionStart, style: .timer)
                .font(.system(size: size * 0.65))
                .monospacedDigit()
                .foregroundStyle(paint)
                .multilineTextAlignment(.center)
                .frame(width: size * 2.6)

        case .pulse:
            Image(systemName: symbolOr("circle.fill"))
                .font(.system(size: size * 0.8))
                .foregroundStyle(paint)
                .scaleEffect(evenFrame ? 1.0 : 0.6)
                .opacity(evenFrame ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.8), value: state.frame)

        case .equalizer:
            EqualizerView(frame: state.frame, active: true, paint: paint, size: size)

        case .musicBars:
            EqualizerView(frame: state.frame, active: state.musicPlaying, paint: paint, size: size)

        case .spin:
            Image(systemName: symbolOr("arrow.triangle.2.circlepath"))
                .font(.system(size: size * 0.8))
                .foregroundStyle(paint)
                .rotationEffect(.degrees(Double(state.frame % 100_000) * 90))
                .animation(.easeInOut(duration: 0.8), value: state.frame)

        case .rainbow:
            Image(systemName: symbolOr("sparkles"))
                .font(.system(size: size * 0.8))
                .foregroundStyle(Color(hue: Double(state.frame % 12) / 12.0, saturation: 0.9, brightness: 1.0))
                .animation(.linear(duration: 0.8), value: state.frame)

        case .marquee:
            Text(Marquee.window(slot.text.isEmpty ? "Island Studio" : slot.text, frame: state.frame, width: marqueeWidth))
                .font(.system(size: marqueeFont))
                .fontDesign(.monospaced)
                .foregroundStyle(paint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

        case .chargeBar:
            ChargeBarView(level: state.battery >= 0 ? Double(state.battery) / 100 : 1,
                          frame: state.frame, paint: paint, outline: c1, size: size)
        }
    }
}

struct EqualizerView: View {
    let frame: Int
    let active: Bool
    let paint: AnyShapeStyle
    let size: CGFloat

    static func height(frame: Int, index: Int) -> CGFloat {
        let seed = ((frame &* 31) &+ (index &* 17)) & 0x7FFF_FFFF
        return 0.3 + CGFloat(seed % 7) / 10.0
    }

    var body: some View {
        HStack(alignment: .center, spacing: size * 0.12) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(paint)
                    .frame(width: size * 0.14,
                           height: size * (active ? Self.height(frame: frame, index: i) : 0.25))
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.6), value: frame)
    }
}

struct ChargeBarView: View {
    let level: Double
    let frame: Int
    let paint: AnyShapeStyle
    let outline: Color
    let size: CGFloat

    var body: some View {
        let w = size * 2.2
        let h = size * 0.5
        ZStack(alignment: .leading) {
            Capsule()
                .stroke(outline.opacity(0.5), lineWidth: 1)
            Capsule()
                .fill(paint)
                .frame(width: max(h, w * min(max(level, 0), 1)))
                .opacity(frame % 2 == 0 ? 1.0 : 0.6)
        }
        .frame(width: w, height: h)
        .animation(.easeInOut(duration: 0.8), value: frame)
    }
}

struct CountdownLabel: View {
    let prefix: String
    let target: Date
    let paint: AnyShapeStyle
    let size: CGFloat

    static func longFormat(_ t: TimeInterval) -> String {
        let total = Int(t)
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        return "\(days)d \(hours)h"
    }

    var body: some View {
        let now = Date()
        let remaining = target.timeIntervalSince(now)
        HStack(spacing: 3) {
            if !prefix.isEmpty { Text(prefix) }
            if remaining <= 0 {
                Text("Now!")
            } else if remaining >= 86_400 {
                Text(Self.longFormat(remaining))
            } else {
                // Under a day: a live ticking countdown, no updates needed.
                Text(timerInterval: now...target, countsDown: true)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(width: size * 3.2)
            }
        }
        .font(.system(size: size * 0.62))
        .foregroundStyle(paint)
        .lineLimit(1)
    }
}
