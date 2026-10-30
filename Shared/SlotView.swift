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

    /// Color that reacts to live data (Live color mode).
    private var liveColor: Color {
        switch slot.content {
        case .crypto:
            return (state.cryptoChange ?? 0) >= 0 ? Color.green : Color.red
        case .pomodoro:
            return state.pomoPhase == "break" ? Color.green : Color(red: 1.0, green: 0.35, blue: 0.3)
        default:
            return c1
        }
    }

    /// Fill for text and icons: solid, gradient, alternating colors, or live.
    private var paint: AnyShapeStyle {
        switch slot.colorMode {
        case .solid:
            return AnyShapeStyle(c1)
        case .gradient:
            return AnyShapeStyle(LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .cycle:
            return AnyShapeStyle(evenFrame ? c1 : c2)
        case .live:
            return AnyShapeStyle(liveColor)
        }
    }

    /// Progress views only take a plain color.
    private var tintColor: Color {
        switch slot.colorMode {
        case .cycle: return evenFrame ? c1 : c2
        case .live: return liveColor
        default: return c1
        }
    }

    private var marqueeWidth: Int { size < 28 ? 8 : 10 }
    private var marqueeFont: CGFloat { min(size * 0.7, 16) }

    private func symbolOr(_ fallback: String) -> String {
        slot.symbol.trimmingCharacters(in: .whitespaces).isEmpty ? fallback : slot.symbol
    }

    private var cycleRange: ClosedRange<Date> {
        state.cycleStart...max(state.cycleEnd, state.cycleStart.addingTimeInterval(1))
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
            let color = BatteryGlyph.autoColor(level: state.battery, charging: state.charging, normal: tintColor)
            HStack(spacing: 4) {
                BatteryGlyph(level: state.battery, charging: state.charging, color: color, size: size * 0.8)
                if state.battery >= 0 { Text("\(state.battery)%") }
            }
            .font(.system(size: size * 0.6))
            .foregroundStyle(color)

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
                    .symbolRenderingMode(slot.colorMode == .live ? SymbolRenderingMode.multicolor
                                                                  : SymbolRenderingMode.monochrome)
                Text(state.weatherTemp.map { "\($0)°" } ?? "--°")
            }
            .font(.system(size: size * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .countdown:
            CountdownLabel(prefix: slot.text, target: state.countdownTarget, paint: paint, size: size)

        case .daysCounter:
            let days = max(0, Calendar.current.dateComponents([.day], from: state.daysSince, to: state.now).day ?? 0)
            HStack(spacing: 3) {
                if slot.text.isEmpty {
                    Image(systemName: "calendar")
                } else {
                    Text(slot.text)
                }
                Text("\(days)d")
            }
            .font(.system(size: size * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .moon:
            let phase = MoonPhase.info(for: state.now)
            HStack(spacing: 3) {
                Image(systemName: phase.symbol)
                Text("\(phase.percent)%")
            }
            .font(.system(size: size * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .crypto:
            HStack(spacing: 3) {
                Text(state.cryptoSymbol.isEmpty ? "BTC" : state.cryptoSymbol)
                Text(CryptoFormat.price(state.cryptoPrice))
                if let change = state.cryptoChange {
                    Image(systemName: change >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: size * 0.32))
                }
            }
            .font(.system(size: size * 0.58))
            .foregroundStyle(paint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .worldClock:
            HStack(spacing: 3) {
                if !slot.text.isEmpty { Text(slot.text) }
                Text(state.now, format: Date.FormatStyle(timeZone: TimeZone(identifier: state.worldTZ) ?? TimeZone.current).hour().minute())
                    .monospacedDigit()
            }
            .font(.system(size: size * 0.66))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .counter:
            HStack(spacing: 3) {
                if !slot.text.isEmpty { Text(slot.text) }
                Text(state.counterGoal > 0 ? "\(state.counter)/\(state.counterGoal)" : "\(state.counter)")
                    .monospacedDigit()
            }
            .font(.system(size: size * 0.64))
            .foregroundStyle(paint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .pomodoro:
            PomodoroLabel(state: state, paint: paint, size: size)

        case .messages:
            Text(Marquee.window(state.rotatingText.isEmpty ? "Add messages in Settings" : state.rotatingText,
                                frame: state.frame, width: marqueeWidth))
                .font(.system(size: marqueeFont))
                .fontDesign(.monospaced)
                .foregroundStyle(paint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

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

// MARK: - Pieces

/// A battery drawn to scale, so it always shows your real level.
struct BatteryGlyph: View {
    let level: Int
    let charging: Bool
    let color: Color
    let size: CGFloat

    /// Green while charging, red when low, orange when getting low, otherwise the normal color.
    static func autoColor(level: Int, charging: Bool, normal: Color) -> Color {
        if charging { return Color.green }
        if level >= 0 && level <= 20 { return Color.red }
        if level >= 0 && level <= 35 { return Color.orange }
        return normal
    }

    var body: some View {
        let w = size * 1.05
        let h = size * 0.52
        let fraction = level < 0 ? 1.0 : min(max(Double(level) / 100, 0), 1)
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: h * 0.3, style: .continuous)
                    .strokeBorder(color.opacity(0.6), lineWidth: 1)
                RoundedRectangle(cornerRadius: h * 0.2, style: .continuous)
                    .fill(color)
                    .frame(width: max(2, (w - 4) * fraction), height: h - 4)
                    .padding(.leading, 2)
            }
            .frame(width: w, height: h)
            RoundedRectangle(cornerRadius: 1)
                .fill(color.opacity(0.6))
                .frame(width: 2, height: h * 0.4)
        }
        .overlay {
            if charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: h * 0.7))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.6), radius: 1)
                    .offset(x: -1)
            }
        }
    }
}

struct PomodoroLabel: View {
    let state: IslandState
    let paint: AnyShapeStyle
    let size: CGFloat

    var body: some View {
        let isFocus = state.pomoPhase != "break"
        HStack(spacing: 3) {
            if state.pomoPhase.isEmpty {
                Image(systemName: "timer")
                Text("Focus")
            } else {
                Text(isFocus ? "🍅" : "☕")
                Text(timerInterval: state.pomoStart...max(state.pomoEnd, state.pomoStart.addingTimeInterval(1)),
                     countsDown: true, showsHours: false)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(width: size * 2.2)
            }
        }
        .font(.system(size: size * 0.62))
        .foregroundStyle(paint)
        .lineLimit(1)
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

// MARK: - Offline helpers

enum MoonPhase {
    static func info(for date: Date) -> (symbol: String, percent: Int, name: String) {
        let synodic = 29.530588853
        // A known new moon: 6 Jan 2000, 18:14 UTC.
        let reference = Date(timeIntervalSince1970: 947_182_440)
        let days = date.timeIntervalSince(reference) / 86_400
        var fraction = days.truncatingRemainder(dividingBy: synodic) / synodic
        if fraction < 0 { fraction += 1 }
        let illumination = (1 - cos(2 * Double.pi * fraction)) / 2
        let symbols = ["moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter",
                       "moonphase.waxing.gibbous", "moonphase.full.moon", "moonphase.waning.gibbous",
                       "moonphase.last.quarter", "moonphase.waning.crescent"]
        let names = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
                     "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
        let index = Int((fraction * 8).rounded()) % 8
        return (symbols[index], Int((illumination * 100).rounded()), names[index])
    }
}

enum CryptoFormat {
    static func price(_ value: Double?) -> String {
        guard let value else { return "--" }
        if value >= 10_000 { return String(format: "$%.1fk", value / 1000) }
        if value >= 100 { return String(format: "$%.0f", value) }
        if value >= 1 { return String(format: "$%.2f", value) }
        return String(format: "$%.4f", value)
    }
}
