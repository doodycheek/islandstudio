import SwiftUI
import UIKit

/// Renders one slot of the island. Shared by the widget (real island) and the app (preview).
/// `decorated: false` skips the slot's shape and offset (used inside Lock Screen badges and rows).
struct SlotView: View {
    let slot: SlotConfig
    let state: IslandState
    var size: CGFloat = 20
    var decorated = true

    /// True on the Always-On Display, where iOS dims everything. We switch to plain bright white.
    @Environment(\.isLuminanceReduced) private var dimmed

    /// Size after the slot's own scale.
    private var sz: CGFloat { size * CGFloat(min(max(slot.scale, 0.5), 1.8)) }

    private var c1: Color { Color(hex: slot.colorHex) }
    private var c2: Color { Color(hex: slot.color2Hex) }
    private var evenFrame: Bool { state.frame % 2 == 0 }

    private var gradientColors: [Color] {
        slot.color3Hex.isEmpty ? [c1, c2] : [c1, c2, Color(hex: slot.color3Hex)]
    }

    private var gradient: LinearGradient {
        let radians = slot.gradientAngle * Double.pi / 180
        let dx = cos(radians) * 0.5
        let dy = sin(radians) * 0.5
        return LinearGradient(colors: gradientColors,
                              startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
                              endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy))
    }

    private var cycleColor: Color {
        let colors = gradientColors
        return colors[((state.frame % colors.count) + colors.count) % colors.count]
    }

    /// Color that reacts to live data (Live color mode).
    private var liveColor: Color {
        switch slot.content {
        case .airQuality:
            let value = state.aqi ?? 0
            if value <= 50 { return Color.green }
            if value <= 100 { return Color.yellow }
            if value <= 150 { return Color.orange }
            return Color.red
        case .uv:
            let value = state.uv ?? 0
            if value >= 8 { return Color.red }
            if value >= 6 { return Color.orange }
            if value >= 3 { return Color.yellow }
            return Color.green
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
        if dimmed { return AnyShapeStyle(Color.white) }
        switch slot.colorMode {
        case .solid: return AnyShapeStyle(c1)
        case .gradient: return AnyShapeStyle(gradient)
        case .cycle: return AnyShapeStyle(cycleColor)
        case .live: return AnyShapeStyle(liveColor)
        }
    }

    /// Progress views and shapes only take a plain color.
    private var tintColor: Color {
        if dimmed { return Color.white }
        switch slot.colorMode {
        case .cycle: return cycleColor
        case .live: return liveColor
        default: return c1
        }
    }

    private var rainbowHue: Double {
        let value = Double(state.frame % 100_000) * max(0.25, slot.speed) / 12
        return value - floor(value)
    }

    /// Frame count for scrolling text, sped up by the slot's text speed.
    private var scrollFrame: Int { state.frame &* max(1, Int(slot.textSpeed.rounded())) }

    private func styled(_ text: String) -> String {
        switch slot.caseStyle {
        case "upper": return text.uppercased()
        case "lower": return text.lowercased()
        default: return text
        }
    }

    private var marqueeWidth: Int { sz < 28 ? 8 : 10 }
    private var marqueeFont: CGFloat { min(sz * 0.7, 16) }

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
            return Color(hue: rainbowHue, saturation: 0.9, brightness: 1.0)
        }
        return slot.content.usesColor ? tintColor : state.accentColor
    }

    private var glowAmount: CGFloat { CGFloat(min(max(state.glowStrength, 0.2), 2.0)) }

    var body: some View {
        content
            .fontDesign(state.design)
            .fontWeight(state.weightValue)
            .fontWidth(state.widthValue)
            .tracking(CGFloat(state.tracking))
            .shadow(color: state.glow ? glowColor.opacity(0.9) : Color.clear,
                    radius: state.glow ? sz * 0.25 * glowAmount : 0)
            .shadow(color: state.glow ? glowColor.opacity(0.5) : Color.clear,
                    radius: state.glow ? sz * 0.5 * glowAmount : 0)
            .shadow(color: slot.textShadow ? Color.black.opacity(0.7) : Color.clear,
                    radius: slot.textShadow ? 1.5 : 0, x: 0, y: slot.textShadow ? 1 : 0)
            .animation(slot.colorMode == .cycle ? Animation.easeInOut(duration: 0.8) : nil, value: state.frame)
            .modifier(SlotMotion(anim: slot.anim, frame: state.frame, size: sz, speed: slot.speed))
            .background {
                if decorated && !dimmed { shapeBackground }
            }
            .overlay(alignment: .topTrailing) {
                if decorated && !slot.badge.isEmpty && !dimmed {
                    Image(systemName: slot.badge)
                        .font(.system(size: max(7, sz * 0.38)))
                        .foregroundStyle(Color(hex: slot.badgeHex))
                        .offset(x: sz * 0.3, y: -sz * 0.25)
                }
            }
            .offset(x: decorated ? CGFloat(slot.offsetX) : 0)
    }

    @ViewBuilder private var shapeBackground: some View {
        switch slot.shape {
        case .none:
            EmptyView()
        case .circle:
            Circle()
                .fill(tintColor.opacity(0.24))
                .padding(-sz * 0.2)
        case .squircle:
            RoundedRectangle(cornerRadius: sz * 0.35, style: .continuous)
                .fill(tintColor.opacity(0.24))
                .padding(-sz * 0.2)
        case .capsule:
            Capsule()
                .fill(tintColor.opacity(0.24))
                .padding(.horizontal, -sz * 0.32)
                .padding(.vertical, -sz * 0.14)
        }
    }

    @ViewBuilder private var content: some View {
        switch slot.content {
        case .empty:
            EmptyView()

        case .text:
            Text(styled(TextVars.resolve(slot.text, state: state)))
                .font(.system(size: sz * 0.75))
                .foregroundStyle(paint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

        case .emoji:
            Text(slot.text)
                .font(.system(size: sz * 0.85))
                .lineLimit(1)

        case .symbol:
            Image(systemName: symbolOr("star.fill"))
                .font(.system(size: sz * 0.8))
                .foregroundStyle(paint)

        case .image:
            if let data = state.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: sz, height: sz)
                    .clipShape(Circle())
            } else {
                Image(systemName: "photo")
                    .font(.system(size: sz * 0.8))
                    .foregroundStyle(paint)
            }

        case .slideshow:
            if let data = state.slideData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: sz, height: sz)
                    .clipShape(RoundedRectangle(cornerRadius: sz * 0.28, style: .continuous))
            } else {
                Image(systemName: "photo.stack")
                    .font(.system(size: sz * 0.8))
                    .foregroundStyle(paint)
            }

        case .clock:
            Text(ClockFormat.string(state.now, seconds: false, hour12: state.hour12))
                .font(.system(size: sz * 0.7))
                .monospacedDigit()
                .foregroundStyle(paint)
                .lineLimit(1)

        case .liveClock:
            LiveClockText(state: state, size: sz * 0.65, paint: paint)

        case .date:
            Text(state.now, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: sz * 0.7))
                .foregroundStyle(paint)
                .lineLimit(1)

        case .battery:
            let color = BatteryGlyph.autoColor(level: state.battery, charging: state.charging, normal: tintColor)
            HStack(spacing: 4) {
                BatteryGlyph(level: state.battery, charging: state.charging, color: color, size: sz * 0.8)
                if state.battery >= 0 { Text("\(state.battery)%") }
            }
            .font(.system(size: sz * 0.6))
            .foregroundStyle(color)

        case .music:
            Text(Marquee.window(styled(musicLine), frame: state.musicPlaying ? scrollFrame : 0, width: marqueeWidth))
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
                    .frame(width: sz, height: sz)
                    .clipShape(RoundedRectangle(cornerRadius: sz * 0.22))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: sz * 0.8))
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
            .font(.system(size: sz * 0.6))
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
            .font(.system(size: sz * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .countdown:
            CountdownLabel(prefix: slot.text, target: state.countdownTarget, paint: paint, size: sz)

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
            .font(.system(size: sz * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .moon:
            let phase = MoonPhase.info(for: state.now)
            HStack(spacing: 3) {
                Image(systemName: phase.symbol)
                Text("\(phase.percent)%")
            }
            .font(.system(size: sz * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .crypto:
            HStack(spacing: 3) {
                Text(state.cryptoSymbol.isEmpty ? "BTC" : state.cryptoSymbol)
                Text(CryptoFormat.price(state.cryptoPrice))
                if let change = state.cryptoChange {
                    Image(systemName: change >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: sz * 0.32))
                }
            }
            .font(.system(size: sz * 0.58))
            .foregroundStyle(paint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .worldClock:
            HStack(spacing: 3) {
                if !slot.text.isEmpty { Text(slot.text) }
                Text(ClockFormat.string(state.now, tz: TimeZone(identifier: state.worldTZ) ?? TimeZone.current,
                                        seconds: false, hour12: state.hour12))
                    .monospacedDigit()
            }
            .font(.system(size: sz * 0.66))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .counter:
            HStack(spacing: 3) {
                if !slot.text.isEmpty { Text(slot.text) }
                Text(state.counterGoal > 0 ? "\(state.counter)/\(state.counterGoal)" : "\(state.counter)")
                    .monospacedDigit()
            }
            .font(.system(size: sz * 0.64))
            .foregroundStyle(paint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .pomodoro:
            PomodoroLabel(state: state, paint: paint, size: sz)

        case .messages:
            Text(Marquee.window(styled(TextVars.resolve(state.rotatingText.isEmpty ? "Add messages in Settings"
                                                                                        : state.rotatingText, state: state)),
                                frame: scrollFrame, width: marqueeWidth))
                .font(.system(size: marqueeFont))
                .fontDesign(.monospaced)
                .foregroundStyle(paint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

        case .nextEvent:
            HStack(spacing: 3) {
                Image(systemName: "calendar")
                Text(state.nextEventTitle.isEmpty ? "No events" : state.nextEventCountdown)
                if sz >= 28 && !state.nextEventTitle.isEmpty {
                    Text(String(state.nextEventTitle.prefix(10)))
                }
            }
            .font(.system(size: sz * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .network:
            Image(systemName: state.netType == "wifi" ? "wifi"
                  : (state.netType == "cell" ? "antenna.radiowaves.left.and.right" : "wifi.slash"))
                .font(.system(size: sz * 0.78))
                .foregroundStyle(paint)

        case .lowPower:
            Image(systemName: state.lowPower ? "battery.25" : "battery.100")
                .font(.system(size: sz * 0.8))
                .foregroundStyle(state.lowPower && !dimmed ? AnyShapeStyle(Color.yellow) : paint)
                .opacity(state.lowPower ? 1 : 0.5)

        case .uv:
            HStack(spacing: 3) {
                Image(systemName: "sun.max.fill")
                Text(state.uv.map { String(format: "%.0f", $0) } ?? "--")
            }
            .font(.system(size: sz * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .rainChance:
            HStack(spacing: 3) {
                Image(systemName: "drop.fill")
                Text(state.rainChance.map { "\($0)%" } ?? "--")
            }
            .font(.system(size: sz * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .wind:
            HStack(spacing: 3) {
                Image(systemName: "wind")
                Text(state.wind.map { "\($0)" } ?? "--")
            }
            .font(.system(size: sz * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .airQuality:
            HStack(spacing: 3) {
                Image(systemName: "leaf.fill")
                Text(state.aqi.map { "\($0)" } ?? "--")
            }
            .font(.system(size: sz * 0.62))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .storage:
            HStack(spacing: 3) {
                Image(systemName: "internaldrive.fill")
                Text(state.storageGB >= 0 ? "\(state.storageGB)GB" : "--")
            }
            .font(.system(size: sz * 0.6))
            .foregroundStyle(paint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .volume:
            HStack(spacing: 3) {
                Image(systemName: state.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                Text(state.volume >= 0 ? "\(state.volume)%" : "--")
            }
            .font(.system(size: sz * 0.6))
            .foregroundStyle(paint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .brightness:
            HStack(spacing: 3) {
                Image(systemName: "sun.min.fill")
                Text(state.brightnessPct >= 0 ? "\(state.brightnessPct)%" : "--")
            }
            .font(.system(size: sz * 0.6))
            .foregroundStyle(paint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .stepsRing:
            let goal = max(1, state.stepsGoal)
            let progress = state.steps >= 0 ? min(1.0, Double(state.steps) / Double(goal)) : 0.0
            RingGauge(progress: progress, color: tintColor, size: sz, symbol: "figure.walk")

        case .dayProgress:
            let start = Calendar.current.startOfDay(for: state.now)
            let progress = min(1.0, max(0.0, state.now.timeIntervalSince(start) / 86_400))
            RingGauge(progress: progress, color: tintColor, size: sz, symbol: "sun.max.fill")

        case .yearProgress:
            let day = Calendar.current.ordinality(of: .day, in: .year, for: state.now) ?? 1
            let total = Calendar.current.range(of: .day, in: .year, for: state.now)?.count ?? 365
            HStack(spacing: 3) {
                Image(systemName: "calendar")
                Text("\(day)/\(total)")
            }
            .font(.system(size: sz * 0.58))
            .foregroundStyle(paint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .streak:
            HStack(spacing: 3) {
                Text(slot.text.isEmpty ? "🔥" : slot.text)
                Text("\(state.streak)").monospacedDigit()
            }
            .font(.system(size: sz * 0.66))
            .foregroundStyle(paint)
            .lineLimit(1)

        case .breathe:
            BreatheView(frame: state.frame, color: tintColor, size: sz, speed: slot.speed)

        case .typewriter:
            let full = styled(TextVars.resolve(slot.text.isEmpty ? "Hello" : slot.text, state: state))
            let chars = Array(full)
            let step = max(1, Int(slot.textSpeed.rounded()))
            let count = (state.frame &* step) % (chars.count + 6)
            let typed = String(chars.prefix(min(count, chars.count)))
            Text(Marquee.tail(typed, width: marqueeWidth) + (count < chars.count ? "▌" : ""))
                .font(.system(size: marqueeFont))
                .fontDesign(.monospaced)
                .foregroundStyle(paint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

        case .analogClock:
            AnalogClockView(date: state.now, color: tintColor, size: sz)

        case .flipClock:
            FlipClockView(text: ClockFormat.string(state.now, seconds: false, hour12: state.hour12),
                          color: tintColor, size: sz)

        case .heartBattery:
            HeartBatteryView(level: state.battery, charging: state.charging, normal: tintColor, size: sz)

        case .bedtime:
            let nowParts = Calendar.current.dateComponents([.hour, .minute], from: state.now)
            let nowMinute = (nowParts.hour ?? 0) * 60 + (nowParts.minute ?? 0)
            let untilBed = (state.bedtimeMinute - nowMinute + 1440) % 1440
            HStack(spacing: 3) {
                Image(systemName: "bed.double.fill")
                Text(untilBed == 0 ? "Now" : (untilBed >= 60 ? "\(untilBed / 60)h \(untilBed % 60)m" : "\(untilBed)m"))
            }
            .font(.system(size: sz * 0.6))
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
            .frame(width: sz, height: sz)

        case .bar:
            ProgressView(timerInterval: cycleRange, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(tintColor)
            .frame(width: sz * 2.5)

        case .timer:
            TimerText(since: state.sessionStart, now: state.now)
                .font(.system(size: sz * 0.65))
                .monospacedDigit()
                .foregroundStyle(paint)
                .multilineTextAlignment(.center)
                .frame(width: sz * 2.6)

        case .pulse:
            Image(systemName: symbolOr("circle.fill"))
                .font(.system(size: sz * 0.8))
                .foregroundStyle(paint)
                .scaleEffect(evenFrame ? 1.0 : 0.6)
                .opacity(evenFrame ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.8 / max(0.25, slot.speed)), value: state.frame)

        case .equalizer:
            EqualizerView(frame: state.frame, active: true, paint: paint, size: sz)

        case .musicBars:
            EqualizerView(frame: state.frame, active: state.musicPlaying, paint: paint, size: sz)

        case .spin:
            Image(systemName: symbolOr("arrow.triangle.2.circlepath"))
                .font(.system(size: sz * 0.8))
                .foregroundStyle(paint)
                .rotationEffect(.degrees(Double(state.frame % 100_000) * 90 * max(0.25, slot.speed)))
                .animation(.easeInOut(duration: 0.8), value: state.frame)

        case .rainbow:
            Image(systemName: symbolOr("sparkles"))
                .font(.system(size: sz * 0.8))
                .foregroundStyle(Color(hue: rainbowHue, saturation: 0.9, brightness: 1.0))
                .animation(.linear(duration: 0.8), value: state.frame)

        case .marquee:
            Text(Marquee.window(styled(TextVars.resolve(slot.text.isEmpty ? "Island Studio" : slot.text, state: state)),
                                frame: scrollFrame, width: marqueeWidth))
                .font(.system(size: marqueeFont))
                .fontDesign(.monospaced)
                .foregroundStyle(paint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

        case .chargeBar:
            ChargeBarView(level: state.battery >= 0 ? Double(state.battery) / 100 : 1,
                          frame: state.frame, paint: paint, outline: c1, size: sz)
        }
    }
}

/// Extra motion any slot can have, driven by the animation step.
struct SlotMotion: ViewModifier {
    let anim: SlotAnim
    let frame: Int
    let size: CGFloat
    let speed: Double

    func body(content: Content) -> some View {
        let even = frame % 2 == 0
        let duration = min(1.6, 0.8 / max(0.25, speed))
        switch anim {
        case .none:
            content
        case .pulse:
            content
                .scaleEffect(even ? 1.0 : 0.78)
                .animation(.easeInOut(duration: duration), value: frame)
        case .bounce:
            content
                .offset(y: even ? 0 : -size * 0.18)
                .animation(.easeOut(duration: duration * 0.6), value: frame)
        case .breathe:
            content
                .opacity(even ? 1.0 : 0.4)
                .animation(.easeInOut(duration: duration), value: frame)
        case .wiggle:
            content
                .rotationEffect(.degrees(even ? -12 : 12))
                .animation(.easeInOut(duration: duration * 0.6), value: frame)
        case .float:
            content
                .offset(y: even ? -size * 0.08 : size * 0.08)
                .animation(.easeInOut(duration: duration), value: frame)
        case .spin:
            content
                .rotationEffect(.degrees(Double(frame % 100_000) * 90))
                .animation(.easeInOut(duration: duration), value: frame)
        case .flip:
            content
                .rotation3DEffect(.degrees(even ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                .animation(.easeInOut(duration: duration), value: frame)
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
                CountdownText(start: state.pomoStart, end: state.pomoEnd, now: state.now, showsHours: false)
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
                CountdownText(start: now, end: target, now: now, showsHours: true)
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

// MARK: - Always-On Display aware pieces

/// The live clock with seconds. Normally it ticks by itself with no updates needed. On the Always-On Display
/// (where iOS turns timers into long text like "6 hours, 12 minutes") it shows the time as plain digits instead.
struct LiveClockText: View {
    let state: IslandState
    let size: CGFloat
    let paint: AnyShapeStyle
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        Group {
            if dimmed {
                Text(ClockFormat.string(state.now, seconds: true, hour12: state.hour12))
            } else if state.hour12 == true {
                twelveHour
            } else {
                Text(Calendar.current.startOfDay(for: Date()), style: .timer)
            }
        }
        .font(.system(size: size))
        .monospacedDigit()
        .foregroundStyle(paint)
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: size * (state.hour12 == true ? 6.6 : 5.2))
    }

    /// 12-hour time that still ticks by itself: count up from midnight, noon, or yesterday's noon.
    private var twelveHour: some View {
        let cal = Calendar.current
        let moment = Date()
        let hour = cal.component(.hour, from: moment)
        let midnight = cal.startOfDay(for: moment)
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: moment) ?? midnight
        let reference: Date
        if hour == 0 {
            reference = cal.date(byAdding: .day, value: -1, to: noon) ?? midnight
        } else if hour >= 13 {
            reference = noon
        } else {
            reference = midnight
        }
        return HStack(spacing: 2) {
            Text(reference, style: .timer)
            Text(hour < 12 ? "AM" : "PM")
                .font(.system(size: size * 0.55, weight: .semibold))
        }
    }
}

/// Counts up from a date. Plain digits on the Always-On Display.
struct TimerText: View {
    let since: Date
    let now: Date
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        if dimmed {
            Text(ClockFormat.duration(now.timeIntervalSince(since)))
        } else {
            Text(since, style: .timer)
        }
    }
}

/// Counts down to a date. Plain digits on the Always-On Display.
struct CountdownText: View {
    let start: Date
    let end: Date
    let now: Date
    var showsHours = true
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        if dimmed {
            Text(ClockFormat.duration(end.timeIntervalSince(now)))
        } else {
            Text(timerInterval: start...max(end, start.addingTimeInterval(1)), countsDown: true, showsHours: showsHours)
        }
    }
}

/// A progress ring with a small icon in the middle.
struct RingGauge: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: size * 0.14)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbol)
                .font(.system(size: size * 0.4))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

/// A ring that swells and shrinks, to pace your breathing.
struct BreatheView: View {
    let frame: Int
    let color: Color
    let size: CGFloat
    let speed: Double

    var body: some View {
        let beats = max(2, Int((4 / max(0.5, speed)).rounded()))
        let inhale = (frame / beats) % 2 == 0
        ZStack {
            Circle()
                .fill(color.opacity(0.22))
                .scaleEffect(inhale ? 1.0 : 0.5)
            Circle()
                .stroke(color, lineWidth: max(1.5, size * 0.1))
                .scaleEffect(inhale ? 1.0 : 0.5)
            if size >= 28 {
                Text(inhale ? "In" : "Out")
                    .font(.system(size: size * 0.3, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: Double(beats) - 0.2), value: inhale)
    }
}

// MARK: - More clock faces and a heart battery

/// A small clock face with hour and minute hands.
struct AnalogClockView: View {
    let date: Date
    let color: Color
    let size: CGFloat

    private func hand(length: CGFloat, width: CGFloat, angle: Double) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: size * length)
            .offset(y: -size * length / 2)
            .rotationEffect(.degrees(angle))
    }

    var body: some View {
        let cal = Calendar.current
        let hour = Double(cal.component(.hour, from: date) % 12)
        let minute = Double(cal.component(.minute, from: date))
        let second = Double(cal.component(.second, from: date))
        ZStack {
            Circle()
                .stroke(color.opacity(0.9), lineWidth: max(1.2, size * 0.07))
            hand(length: 0.27, width: max(1.5, size * 0.07), angle: (hour + minute / 60) / 12 * 360)
            hand(length: 0.4, width: max(1.2, size * 0.05), angle: (minute + second / 60) / 60 * 360)
            Circle()
                .fill(color)
                .frame(width: size * 0.1, height: size * 0.1)
        }
        .frame(width: size, height: size)
    }
}

/// Digits on little flip cards.
struct FlipClockView: View {
    let text: String
    let color: Color
    let size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.08) {
            ForEach(Array(text.enumerated()), id: \.offset) { item in
                let character = String(item.element)
                if item.element.isNumber {
                    Text(character)
                        .font(.system(size: size * 0.6, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(color)
                        .frame(width: size * 0.5, height: size * 0.8)
                        .background(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous).fill(color.opacity(0.2)))
                        .overlay(Rectangle().fill(Color.black.opacity(0.55)).frame(height: 1))
                } else if character == " " {
                    Spacer().frame(width: size * 0.04)
                } else {
                    Text(character)
                        .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
            }
        }
        .fixedSize()
    }
}

/// A heart that empties as the battery drains.
struct HeartBatteryView: View {
    let level: Int
    let charging: Bool
    let normal: Color
    let size: CGFloat

    var body: some View {
        let fraction = level < 0 ? 1.0 : min(max(Double(level) / 100, 0), 1)
        let color = BatteryGlyph.autoColor(level: level, charging: charging, normal: normal)
        ZStack {
            Image(systemName: "heart")
                .font(.system(size: size * 0.9, weight: .bold))
                .foregroundStyle(color.opacity(0.4))
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.9, weight: .bold))
                .foregroundStyle(color)
                .mask {
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle().frame(height: geo.size.height * CGFloat(fraction))
                        }
                    }
                }
        }
        .frame(width: size, height: size)
    }
}
