import ActivityKit
import SwiftUI
import UIKit

struct IslandAttributes: ActivityAttributes {
    public typealias ContentState = IslandState
    var name: String
}

// MARK: - What a slot can show

enum SlotCategory: String, CaseIterable, Identifiable {
    case basic, info, animated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "Static"
        case .info: return "Live info"
        case .animated: return "Animated"
        }
    }

    var items: [SlotContent] { SlotContent.allCases.filter { $0.category == self } }
}

enum SlotContent: String, Codable, CaseIterable, Identifiable, Hashable {
    case empty, text, emoji, symbol, image
    case clock, liveClock, date, battery, music, musicArt, steps, weather, countdown
    case ring, bar, timer, pulse, equalizer, spin, rainbow, marquee, musicBars, chargeBar

    var id: String { rawValue }

    var category: SlotCategory {
        switch self {
        case .empty, .text, .emoji, .symbol, .image:
            return .basic
        case .clock, .liveClock, .date, .battery, .music, .musicArt, .steps, .weather, .countdown:
            return .info
        case .ring, .bar, .timer, .pulse, .equalizer, .spin, .rainbow, .marquee, .musicBars, .chargeBar:
            return .animated
        }
    }

    var label: String {
        switch self {
        case .empty: return "Nothing"
        case .text: return "Text"
        case .emoji: return "Emoji"
        case .symbol: return "Icon (SF Symbol)"
        case .image: return "My photo"
        case .clock: return "Clock"
        case .liveClock: return "Live clock (seconds)"
        case .date: return "Date"
        case .battery: return "Battery"
        case .music: return "Now playing"
        case .musicArt: return "Album art"
        case .steps: return "Steps"
        case .weather: return "Weather"
        case .countdown: return "Countdown"
        case .ring: return "Looping ring"
        case .bar: return "Looping bar"
        case .timer: return "Running timer"
        case .pulse: return "Pulse"
        case .equalizer: return "Equalizer"
        case .spin: return "Spin"
        case .rainbow: return "Rainbow"
        case .marquee: return "Scrolling text"
        case .musicBars: return "Music bars"
        case .chargeBar: return "Charging bar"
        }
    }

    var icon: String {
        switch self {
        case .empty: return "nosign"
        case .text: return "textformat"
        case .emoji: return "face.smiling"
        case .symbol: return "star"
        case .image: return "photo"
        case .clock: return "clock"
        case .liveClock: return "clock.arrow.circlepath"
        case .date: return "calendar"
        case .battery: return "battery.75"
        case .music: return "music.note"
        case .musicArt: return "photo.artframe"
        case .steps: return "figure.walk"
        case .weather: return "cloud.sun.fill"
        case .countdown: return "hourglass"
        case .ring: return "circle.dashed"
        case .bar: return "rectangle.fill"
        case .timer: return "stopwatch"
        case .pulse: return "dot.radiowaves.left.and.right"
        case .equalizer: return "waveform"
        case .spin: return "arrow.triangle.2.circlepath"
        case .rainbow: return "sparkles"
        case .marquee: return "text.alignleft"
        case .musicBars: return "waveform.path"
        case .chargeBar: return "battery.100.bolt"
        }
    }

    var hint: String? {
        switch self {
        case .music, .musicArt, .musicBars:
            return "Reads the built-in Music app. iOS doesn't let apps read Spotify or other players."
        case .steps:
            return "Today's steps from your iPhone's motion sensor."
        case .weather:
            return "Current weather for your saved location. Set it under Live info."
        case .countdown:
            return "Set the date under Live info. Add an emoji or short label below."
        case .marquee:
            return "Scrolls one letter per animation step. Lower the animation step for faster scrolling."
        case .chargeBar:
            return "Shows your battery level as a glowing bar."
        case .clock:
            return "Refreshes while the app runs in the background."
        case .liveClock:
            return "Ticks every second on its own, in 24-hour time."
        case .image:
            return "Pick the photo on the main screen under My photo."
        default:
            return nil
        }
    }

    var textPlaceholder: String {
        switch self {
        case .emoji: return "Emoji"
        case .countdown: return "Label or emoji (optional)"
        case .marquee: return "Scrolling message"
        default: return "Text"
        }
    }

    var usesText: Bool { self == .text || self == .emoji || self == .marquee || self == .countdown }
    var usesSymbol: Bool { self == .symbol || self == .pulse || self == .spin || self == .rainbow }
    /// Compact, square-ish content (gets a round badge on the Lock Screen). Text-like content gets a pill.
    var isIconLike: Bool {
        switch self {
        case .symbol, .emoji, .image, .musicArt, .ring, .pulse, .spin, .rainbow, .equalizer, .musicBars:
            return true
        default:
            return false
        }
    }

    var usesColor: Bool {
        !(self == .empty || self == .emoji || self == .image || self == .rainbow || self == .musicArt)
    }
}

enum LockStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case tinted, black, glass

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tinted: return "Tinted"
        case .black: return "Black"
        case .glass: return "Glass"
        }
    }
}

enum ColorMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case solid, gradient, cycle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solid: return "Solid"
        case .gradient: return "Gradient"
        case .cycle: return "Cycle"
        }
    }
}

// MARK: - Slot

struct SlotConfig: Codable, Hashable {
    var content: SlotContent = .empty
    var text: String = ""
    var symbol: String = "star.fill"
    var colorHex: String = "FFFFFFFF"
    var color2Hex: String = "FF2D92FF"
    var colorMode: ColorMode = .solid

    enum CodingKeys: String, CodingKey {
        case content, text, symbol, colorHex, color2Hex, colorMode
    }
}

extension SlotConfig {
    // Tolerant decoding: missing fields fall back to defaults, so older saved data still loads.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content = c.value(.content, default: content)
        text = c.value(.text, default: text)
        symbol = c.value(.symbol, default: symbol)
        colorHex = c.value(.colorHex, default: colorHex)
        color2Hex = c.value(.color2Hex, default: color2Hex)
        colorMode = c.value(.colorMode, default: colorMode)
    }
}

// MARK: - Island state

/// Everything the island needs. ActivityKit caps this at 4 KB total, so keep it lean.
struct IslandState: Codable, Hashable {
    // Style (what presets save)
    var left = SlotConfig(content: .ring, colorHex: "00E5FFFF")
    var right = SlotConfig(content: .battery, colorHex: "34C759FF")
    var minimal = SlotConfig(content: .pulse, symbol: "circle.fill", colorHex: "00E5FFFF")
    var expandedTitle = "Island Studio"
    var expandedSubtitle = "Your island, your rules"
    var keylineHex = "00E5FFFF"
    var fontDesign = "rounded"
    var bold = true
    var imageData: Data? = nil
    var lockStyle: LockStyle = .tinted
    var lockChips = true
    var lockAccent = true

    // Live values the app keeps refreshing
    var frame = 0
    var cycleStart = Date()
    var cycleEnd = Date().addingTimeInterval(3)
    var sessionStart = Date()
    var now = Date()
    var battery = -1
    var charging = false
    var paused = false
    var showButtons = true
    var bannerText = ""
    var countdownTarget = Date().addingTimeInterval(7 * 86_400)
    var musicTitle = ""
    var musicArtist = ""
    var musicPlaying = false
    var musicArt: Data? = nil
    var steps = -1
    var weatherTemp: Int? = nil
    var weatherSymbol = ""

    enum CodingKeys: String, CodingKey {
        case left, right, minimal, expandedTitle, expandedSubtitle, keylineHex, fontDesign, bold, imageData
        case lockStyle, lockChips, lockAccent
        case frame, cycleStart, cycleEnd, sessionStart, now, battery, charging, paused, showButtons, bannerText
        case countdownTarget, musicTitle, musicArtist, musicPlaying, musicArt, steps, weatherTemp, weatherSymbol
    }

    var design: Font.Design {
        switch fontDesign {
        case "rounded": return .rounded
        case "monospaced": return .monospaced
        case "serif": return .serif
        default: return .default
        }
    }
}

extension IslandState {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        left = c.value(.left, default: left)
        right = c.value(.right, default: right)
        minimal = c.value(.minimal, default: minimal)
        expandedTitle = c.value(.expandedTitle, default: expandedTitle)
        expandedSubtitle = c.value(.expandedSubtitle, default: expandedSubtitle)
        keylineHex = c.value(.keylineHex, default: keylineHex)
        fontDesign = c.value(.fontDesign, default: fontDesign)
        bold = c.value(.bold, default: bold)
        imageData = c.optional(.imageData)
        lockStyle = c.value(.lockStyle, default: lockStyle)
        lockChips = c.value(.lockChips, default: lockChips)
        lockAccent = c.value(.lockAccent, default: lockAccent)
        frame = c.value(.frame, default: frame)
        cycleStart = c.value(.cycleStart, default: cycleStart)
        cycleEnd = c.value(.cycleEnd, default: cycleEnd)
        sessionStart = c.value(.sessionStart, default: sessionStart)
        now = c.value(.now, default: now)
        battery = c.value(.battery, default: battery)
        charging = c.value(.charging, default: charging)
        paused = c.value(.paused, default: paused)
        showButtons = c.value(.showButtons, default: showButtons)
        bannerText = c.value(.bannerText, default: bannerText)
        countdownTarget = c.value(.countdownTarget, default: countdownTarget)
        musicTitle = c.value(.musicTitle, default: musicTitle)
        musicArtist = c.value(.musicArtist, default: musicArtist)
        musicPlaying = c.value(.musicPlaying, default: musicPlaying)
        musicArt = c.optional(.musicArt)
        steps = c.value(.steps, default: steps)
        weatherTemp = c.optional(.weatherTemp)
        weatherSymbol = c.value(.weatherSymbol, default: weatherSymbol)
    }

    func uses(_ content: SlotContent) -> Bool {
        left.content == content || right.content == content || minimal.content == content
    }

    func usesAny(_ list: [SlotContent]) -> Bool {
        list.contains { uses($0) }
    }

    var encodedSize: Int {
        (try? JSONEncoder().encode(self))?.count ?? 0
    }

    /// Drops the heaviest optional data until the state fits ActivityKit's 4 KB limit.
    mutating func fitToBudget(limit: Int = 3800) {
        if encodedSize > limit { musicArt = nil }
        if encodedSize > limit { imageData = nil }
        if encodedSize > limit {
            musicTitle = String(musicTitle.prefix(20))
            musicArtist = ""
            expandedSubtitle = String(expandedSubtitle.prefix(20))
        }
    }

    /// Used by "Show the music": album art + music bars, song as the long-press title.
    mutating func applyMusicStyle() {
        left = SlotConfig(content: .musicArt)
        right = SlotConfig(content: .musicBars, colorHex: "FF2D55FF")
        minimal = SlotConfig(content: .musicBars, colorHex: "FF2D55FF")
        if !musicTitle.isEmpty {
            expandedTitle = musicTitle
            expandedSubtitle = musicArtist
        }
    }

    /// Accent color without its alpha, for badges, bars and buttons.
    var accentColor: Color { Color(hex: String(keylineHex.prefix(6))) }

    /// Background behind the Lock Screen card.
    var lockBackground: Color {
        switch lockStyle {
        case .black: return Color.black.opacity(0.92)
        case .tinted: return accentColor.darker(0.25)
        case .glass: return Color.black.opacity(0.28)
        }
    }

    mutating func applyChargingStyle() {
        left = SlotConfig(content: .pulse, symbol: "bolt.fill", colorHex: "34C759FF")
        right = SlotConfig(content: .chargeBar, colorHex: "34C759FF")
        minimal = SlotConfig(content: .pulse, symbol: "bolt.fill", colorHex: "34C759FF")
    }

    /// A copy with only the style fields, used for saving and sharing presets.
    func styleOnly() -> IslandState {
        var s = IslandState()
        s.left = left
        s.right = right
        s.minimal = minimal
        s.expandedTitle = expandedTitle
        s.expandedSubtitle = expandedSubtitle
        s.keylineHex = keylineHex
        s.fontDesign = fontDesign
        s.bold = bold
        s.imageData = imageData
        s.lockStyle = lockStyle
        s.lockChips = lockChips
        s.lockAccent = lockAccent
        return s
    }
}

// MARK: - Helpers

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }

    func optional<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }
}

enum Marquee {
    /// A sliding window over the text, one character per frame.
    static func window(_ text: String, frame: Int, width: Int) -> String {
        let chars = Array(text)
        guard width > 0, chars.count > width else { return text }
        let loop = chars + Array("   •   ")
        let start = ((frame % loop.count) + loop.count) % loop.count
        return String((0..<width).map { loop[(start + $0) % loop.count] })
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        s = s.replacingOccurrences(of: "#", with: "")
        if s.count == 6 { s += "FF" }
        var value: UInt64 = 0
        guard s.count == 8, Scanner(string: s).scanHexInt64(&value) else {
            self = .white
            return
        }
        let r = Double((value >> 24) & 0xFF) / 255
        let g = Double((value >> 16) & 0xFF) / 255
        let b = Double((value >> 8) & 0xFF) / 255
        let a = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func darker(_ factor: Double) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(.sRGB, red: Double(r) * factor, green: Double(g) * factor, blue: Double(b) * factor, opacity: 1)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X%02X", c(r), c(g), c(b), c(a))
    }
}
