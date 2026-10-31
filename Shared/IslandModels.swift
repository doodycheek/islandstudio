import ActivityKit
import SwiftUI
import UIKit

struct IslandAttributes: ActivityAttributes {
    public typealias ContentState = IslandState
    var name: String
}

// MARK: - What a slot can show

enum SlotCategory: String, CaseIterable, Identifiable {
    case basic, info, tools, animated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "Static"
        case .info: return "Live info"
        case .tools: return "Tools"
        case .animated: return "Animated"
        }
    }

    var items: [SlotContent] { SlotContent.allCases.filter { $0.category == self } }
}

enum SlotContent: String, Codable, CaseIterable, Identifiable, Hashable {
    case empty, text, emoji, symbol, image, slideshow
    case clock, liveClock, date, battery, music, musicArt, steps, weather, countdown
    case daysCounter, moon, crypto, worldClock
    case nextEvent, network, lowPower, uv, rainChance, wind, airQuality, storage, volume, brightness, stepsRing
    case dayProgress, yearProgress
    case counter, pomodoro, messages, streak
    case ring, bar, timer, pulse, equalizer, spin, rainbow, marquee, musicBars, chargeBar, breathe, typewriter

    var id: String { rawValue }

    var category: SlotCategory {
        switch self {
        case .empty, .text, .emoji, .symbol, .image, .slideshow:
            return .basic
        case .clock, .liveClock, .date, .battery, .music, .musicArt, .steps, .weather, .countdown,
             .daysCounter, .moon, .crypto, .worldClock,
             .nextEvent, .network, .lowPower, .uv, .rainChance, .wind, .airQuality, .storage, .volume,
             .brightness, .stepsRing, .dayProgress, .yearProgress:
            return .info
        case .counter, .pomodoro, .messages, .streak:
            return .tools
        case .ring, .bar, .timer, .pulse, .equalizer, .spin, .rainbow, .marquee, .musicBars, .chargeBar,
             .breathe, .typewriter:
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
        case .slideshow: return "Photo slideshow"
        case .clock: return "Clock"
        case .liveClock: return "Live clock (seconds)"
        case .date: return "Date"
        case .battery: return "Battery"
        case .music: return "Now playing"
        case .musicArt: return "Album art"
        case .steps: return "Steps"
        case .weather: return "Weather"
        case .countdown: return "Countdown"
        case .daysCounter: return "Days counter"
        case .moon: return "Moon phase"
        case .crypto: return "Crypto price"
        case .worldClock: return "World clock"
        case .nextEvent: return "Next calendar event"
        case .network: return "Wi-Fi / cellular"
        case .lowPower: return "Low Power Mode"
        case .uv: return "UV index"
        case .rainChance: return "Chance of rain"
        case .wind: return "Wind speed"
        case .airQuality: return "Air quality"
        case .storage: return "Free storage"
        case .volume: return "Volume"
        case .brightness: return "Screen brightness"
        case .stepsRing: return "Steps goal ring"
        case .dayProgress: return "Day progress"
        case .yearProgress: return "Year progress"
        case .counter: return "Tap counter"
        case .pomodoro: return "Focus timer"
        case .messages: return "Rotating messages"
        case .streak: return "Goal streak"
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
        case .breathe: return "Breathing guide"
        case .typewriter: return "Typewriter text"
        }
    }

    var icon: String {
        switch self {
        case .empty: return "nosign"
        case .text: return "textformat"
        case .emoji: return "face.smiling"
        case .symbol: return "star"
        case .image: return "photo"
        case .slideshow: return "photo.stack"
        case .clock: return "clock"
        case .liveClock: return "clock.arrow.circlepath"
        case .date: return "calendar"
        case .battery: return "battery.75"
        case .music: return "music.note"
        case .musicArt: return "photo.artframe"
        case .steps: return "figure.walk"
        case .weather: return "cloud.sun.fill"
        case .countdown: return "hourglass"
        case .daysCounter: return "calendar.badge.clock"
        case .moon: return "moonphase.waxing.gibbous"
        case .crypto: return "bitcoinsign.circle.fill"
        case .worldClock: return "globe"
        case .nextEvent: return "calendar.circle.fill"
        case .network: return "wifi"
        case .lowPower: return "battery.25"
        case .uv: return "sun.max.fill"
        case .rainChance: return "drop.fill"
        case .wind: return "wind"
        case .airQuality: return "leaf.fill"
        case .storage: return "internaldrive.fill"
        case .volume: return "speaker.wave.2.fill"
        case .brightness: return "sun.min.fill"
        case .stepsRing: return "figure.walk.circle.fill"
        case .dayProgress: return "sun.horizon.fill"
        case .yearProgress: return "calendar"
        case .counter: return "plus.circle.fill"
        case .pomodoro: return "timer"
        case .messages: return "text.bubble.fill"
        case .streak: return "flame.fill"
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
        case .breathe: return "lungs.fill"
        case .typewriter: return "keyboard"
        }
    }

    var hint: String? {
        switch self {
        case .music, .musicArt, .musicBars:
            return "Reads the built-in Music app. iOS doesn't let apps read Spotify or other players."
        case .steps:
            return "Today's steps from your iPhone's motion sensor."
        case .weather:
            return "Shows the real current weather: rain, sun, snow and so on. Set your location under Settings → Live info."
        case .countdown:
            return "Set the date under Settings → Live info. Add an emoji or short label below."
        case .battery:
            return "Shows your real battery level. Turns green while charging and red under 20%."
        case .daysCounter:
            return "Counts days since the date you set under Settings → Tools."
        case .moon:
            return "Today's moon phase and how lit it is. Works offline."
        case .crypto:
            return "Price and 24-hour change from CoinGecko. Pick the coin under Settings → Tools."
        case .worldClock:
            return "The time in another city. Pick the city under Settings → Tools."
        case .counter:
            return "Long-press the island to tap + and −. Set a goal under Settings → Tools."
        case .pomodoro:
            return "Start it from the long-press view or Settings → Tools. Pops out when each phase ends."
        case .messages:
            return "Cycles through your own messages. Edit them under Settings → Tools."
        case .slideshow:
            return "Cycles through up to 4 photos. Pick them under Settings → Tools."
        case .marquee:
            return "Scrolls one letter per animation step. Lower the animation step for faster scrolling."
        case .chargeBar:
            return "Shows your battery level as a glowing bar."
        case .clock:
            return "Refreshes while the app runs in the background."
        case .liveClock:
            return "Ticks every second on its own. Pick 12 or 24-hour under Style → Clock format."
        case .image:
            return "Pick the photo on the main screen under My photo."
        case .nextEvent:
            return "Time until your next calendar event. The first time, iOS asks for calendar access."
        case .network:
            return "Shows whether you're on Wi-Fi, cellular or offline."
        case .lowPower:
            return "Lights up yellow when Low Power Mode is on."
        case .uv:
            return "Today's UV index for your location. Set your location under Settings → Live info."
        case .rainChance:
            return "Chance of rain this hour. Set your location under Settings → Live info."
        case .wind:
            return "Wind speed right now. Set your location under Settings → Live info."
        case .airQuality:
            return "US air quality index. Live color goes green, yellow, orange, red."
        case .storage:
            return "How much free space your iPhone has left."
        case .volume:
            return "Your current volume."
        case .brightness:
            return "Your current screen brightness."
        case .stepsRing:
            return "A ring that fills as you walk toward your daily step goal."
        case .dayProgress:
            return "How much of today has gone by, as a ring."
        case .yearProgress:
            return "Which day of the year it is."
        case .streak:
            return "Days in a row you've hit your counter goal. Set the goal under Settings → Tools."
        case .breathe:
            return "A ring that grows and shrinks to pace your breathing. Speed changes the rhythm."
        case .typewriter:
            return "Types your text out one letter at a time. Text can use {battery}, {time} and more."
        default:
            return nil
        }
    }

    var textPlaceholder: String {
        switch self {
        case .emoji: return "Emoji"
        case .countdown: return "Label or emoji (optional)"
        case .marquee: return "Scrolling message (can use {battery}, {time}…)"
        case .typewriter: return "Text to type out"
        case .streak: return "Emoji (optional, like 🔥)"
        case .counter: return "Emoji (optional, like 💧)"
        case .daysCounter: return "Emoji or label (like 💜)"
        case .worldClock: return "City or emoji (like 🇯🇵)"
        default: return "Text"
        }
    }

    var usesText: Bool {
        self == .text || self == .emoji || self == .marquee || self == .countdown
            || self == .counter || self == .daysCounter || self == .worldClock
            || self == .typewriter || self == .streak
    }

    var usesSymbol: Bool { self == .symbol || self == .pulse || self == .spin || self == .rainbow }

    /// Compact, square-ish content (gets a round badge on the Lock Screen). Text-like content gets a pill.
    var isIconLike: Bool {
        switch self {
        case .symbol, .emoji, .image, .slideshow, .musicArt, .ring, .pulse, .spin, .rainbow, .equalizer, .musicBars,
             .breathe, .stepsRing, .dayProgress, .network, .lowPower:
            return true
        default:
            return false
        }
    }

    var usesColor: Bool {
        !(self == .empty || self == .emoji || self == .image || self == .slideshow
            || self == .rainbow || self == .musicArt)
    }
}

// MARK: - Style options

enum LockStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case tinted, black, glass, gradient, custom, aurora

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tinted: return "Tinted"
        case .black: return "Black"
        case .glass: return "Glass"
        case .gradient: return "Gradient"
        case .custom: return "Custom"
        case .aurora: return "Aurora"
        }
    }
}

enum LockLayout: String, Codable, CaseIterable, Identifiable, Hashable {
    case classic, compact, hero, clock

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic: return "Classic"
        case .compact: return "Compact"
        case .hero: return "Hero"
        case .clock: return "Big clock"
        }
    }
}

/// What the Lock Screen / expanded progress bar shows.
enum LockBar: String, Codable, CaseIterable, Identifiable, Hashable {
    case loop, day, battery, counter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .loop: return "Loop"
        case .day: return "Day"
        case .battery: return "Battery"
        case .counter: return "Counter"
        }
    }
}

enum BadgeStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case circle, squircle, none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .circle: return "Circle"
        case .squircle: return "Squircle"
        case .none: return "None"
        }
    }
}

enum ExpandedLayout: String, Codable, CaseIterable, Identifiable, Hashable {
    case standard, centered, big

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Standard"
        case .centered: return "Big title"
        case .big: return "Big icons"
        }
    }
}

/// A colored backing behind the island's icons and text.
enum IslandBG: String, Codable, CaseIterable, Identifiable, Hashable {
    case none, tint, gradient

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Off"
        case .tint: return "Tint"
        case .gradient: return "Gradient"
        }
    }
}

/// Where the accent color comes from.
enum AccentSync: String, Codable, CaseIterable, Identifiable, Hashable {
    case fixed, timeOfDay, battery, weather, albumArt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fixed: return "My color"
        case .timeOfDay: return "Time of day"
        case .battery: return "Battery"
        case .weather: return "Weather"
        case .albumArt: return "Album art"
        }
    }

    var icon: String {
        switch self {
        case .fixed: return "paintpalette.fill"
        case .timeOfDay: return "sun.horizon.fill"
        case .battery: return "battery.75"
        case .weather: return "cloud.sun.fill"
        case .albumArt: return "photo.artframe"
        }
    }
}

enum ColorMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case solid, gradient, cycle, live

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solid: return "Solid"
        case .gradient: return "Gradient"
        case .cycle: return "Cycle"
        case .live: return "Live"
        }
    }
}

enum SlotShape: String, Codable, CaseIterable, Identifiable, Hashable {
    case none, circle, squircle, capsule

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .circle: return "Circle"
        case .squircle: return "Squircle"
        case .capsule: return "Pill"
        }
    }
}

/// A motion any slot can have, on top of its content.
enum SlotAnim: String, Codable, CaseIterable, Identifiable, Hashable {
    case none, pulse, bounce, breathe, wiggle, float, spin, flip

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .pulse: return "Pulse"
        case .bounce: return "Bounce"
        case .breathe: return "Breathe"
        case .wiggle: return "Wiggle"
        case .float: return "Float"
        case .spin: return "Spin"
        case .flip: return "Flip"
        }
    }
}

/// Info chips for the Lock Screen and expanded view.
enum ChipKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case battery, weather, steps, date, moon, counter, crypto, countdown, focus
    case nextEvent, uv, rain, wind, aqi, network, storage, streak

    var id: String { rawValue }

    var label: String {
        switch self {
        case .battery: return "Battery"
        case .weather: return "Weather"
        case .steps: return "Steps"
        case .date: return "Date"
        case .moon: return "Moon"
        case .counter: return "Counter"
        case .crypto: return "Crypto"
        case .countdown: return "Countdown"
        case .focus: return "Focus"
        case .nextEvent: return "Next event"
        case .uv: return "UV"
        case .rain: return "Rain chance"
        case .wind: return "Wind"
        case .aqi: return "Air quality"
        case .network: return "Network"
        case .storage: return "Storage"
        case .streak: return "Streak"
        }
    }
}

/// Buttons you can put in the long-press view.
enum ButtonKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case prev, next, pause, counterPlus, counterMinus, focus, musicPrevious, musicPlayPause, musicNext, surprise

    var id: String { rawValue }

    var label: String {
        switch self {
        case .prev: return "Previous preset"
        case .next: return "Next preset"
        case .pause: return "Pause animation"
        case .counterPlus: return "Counter +1"
        case .counterMinus: return "Counter −1"
        case .focus: return "Focus timer"
        case .musicPrevious: return "Music: previous"
        case .musicPlayPause: return "Music: play/pause"
        case .musicNext: return "Music: next"
        case .surprise: return "Surprise preset"
        }
    }

    var icon: String {
        switch self {
        case .prev: return "chevron.left.circle.fill"
        case .next: return "chevron.right.circle.fill"
        case .pause: return "pause.circle.fill"
        case .counterPlus: return "plus.circle.fill"
        case .counterMinus: return "minus.circle.fill"
        case .focus: return "timer"
        case .musicPrevious: return "backward.fill"
        case .musicPlayPause: return "playpause.fill"
        case .musicNext: return "forward.fill"
        case .surprise: return "shuffle"
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
    var color3Hex: String = ""
    var gradientAngle: Double = 135
    var useAccent = false
    var scale: Double = 1
    var offsetX: Double = 0
    var shape: SlotShape = .none
    var anim: SlotAnim = .none
    var speed: Double = 1
    var badge: String = ""
    var badgeHex: String = "FF3B30FF"
    var caseStyle: String = ""
    var textShadow = false
    var textSpeed: Double = 1

    enum CodingKeys: String, CodingKey {
        case content, text, symbol, colorHex, color2Hex, colorMode
        case color3Hex, gradientAngle, useAccent, scale, offsetX, shape, anim, speed
        case badge, badgeHex, caseStyle, textShadow, textSpeed
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
        color3Hex = c.value(.color3Hex, default: color3Hex)
        gradientAngle = c.value(.gradientAngle, default: gradientAngle)
        useAccent = c.value(.useAccent, default: useAccent)
        scale = c.value(.scale, default: scale)
        offsetX = c.value(.offsetX, default: offsetX)
        shape = c.value(.shape, default: shape)
        anim = c.value(.anim, default: anim)
        speed = c.value(.speed, default: speed)
        badge = c.value(.badge, default: badge)
        badgeHex = c.value(.badgeHex, default: badgeHex)
        caseStyle = c.value(.caseStyle, default: caseStyle)
        textShadow = c.value(.textShadow, default: textShadow)
        textSpeed = c.value(.textSpeed, default: textSpeed)
    }

    // Compact encoding: values left at their default aren't written, keeping the island under 4 KB.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let d = SlotConfig()
        try c.put(content, d.content, .content)
        try c.put(text, d.text, .text)
        try c.put(symbol, d.symbol, .symbol)
        try c.put(colorHex, d.colorHex, .colorHex)
        try c.put(color2Hex, d.color2Hex, .color2Hex)
        try c.put(colorMode, d.colorMode, .colorMode)
        try c.put(color3Hex, d.color3Hex, .color3Hex)
        try c.put(gradientAngle, d.gradientAngle, .gradientAngle)
        try c.put(useAccent, d.useAccent, .useAccent)
        try c.put(scale, d.scale, .scale)
        try c.put(offsetX, d.offsetX, .offsetX)
        try c.put(shape, d.shape, .shape)
        try c.put(anim, d.anim, .anim)
        try c.put(speed, d.speed, .speed)
        try c.put(badge, d.badge, .badge)
        try c.put(badgeHex, d.badgeHex, .badgeHex)
        try c.put(caseStyle, d.caseStyle, .caseStyle)
        try c.put(textShadow, d.textShadow, .textShadow)
        try c.put(textSpeed, d.textSpeed, .textSpeed)
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
    var lockLayout: LockLayout = .classic
    var lockOwnText = false
    var lockTitle = ""
    var lockSubtitle = ""
    var glow = false
    var expandedChips = false
    var expandedBar = false
    var islandBg: IslandBG = .none
    var fontWeight = ""
    var fontWidth = "standard"
    var tracking: Double = 0
    var glowStrength: Double = 1
    var accentSync: AccentSync = .fixed
    var expandedLayout: ExpandedLayout = .standard
    var expandedTitleHex = ""
    var expandedIcon = ""
    var lockTitleHex = ""
    var lockIcon = ""
    var lockBgHex = "1C1C3AFF"
    var lockBg2Hex = "4A1C6AFF"
    var lockBarStyle: LockBar = .loop
    var badgeStyle: BadgeStyle = .circle
    var chipKinds: [String] = ["battery", "weather", "steps", "date"]

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
    var rotatingText = ""
    var counter = 0
    var counterGoal = 0
    var showCounterButtons = false
    var showTimerButton = false
    var pomoPhase = ""
    var pomoStart = Date()
    var pomoEnd = Date()
    var daysSince = Date()
    var cryptoSymbol = ""
    var cryptoPrice: Double? = nil
    var cryptoChange: Double? = nil
    var worldTZ = ""
    var slideData: Data? = nil
    var buttonKinds: [String] = ["prev", "pause", "next"]
    var minimalRing = true
    var clockMode = "auto"
    var lockAlign = "leading"
    var graphKind = ""
    var spark: [Int] = []
    var reactions: [String] = []
    var nextEventTitle = ""
    var nextEventStart = Date()
    var netType = ""
    var lowPower = false
    var uv: Double? = nil
    var rainChance: Int? = nil
    var wind: Int? = nil
    var aqi: Int? = nil
    var storageGB = -1
    var volume = -1
    var brightnessPct = -1
    var stepsGoal = 10_000
    var streak = 0

    enum CodingKeys: String, CodingKey {
        case left, right, minimal, expandedTitle, expandedSubtitle, keylineHex, fontDesign, bold, imageData
        case lockStyle, lockChips, lockAccent, lockLayout, lockOwnText, lockTitle, lockSubtitle
        case glow, expandedChips, expandedBar, islandBg
        case fontWeight, fontWidth, tracking, glowStrength, accentSync, expandedLayout, expandedTitleHex, expandedIcon
        case lockTitleHex, lockIcon, lockBgHex, lockBg2Hex, lockBarStyle, badgeStyle, chipKinds
        case frame, cycleStart, cycleEnd, sessionStart, now, battery, charging, paused, showButtons, bannerText
        case countdownTarget, musicTitle, musicArtist, musicPlaying, musicArt, steps, weatherTemp, weatherSymbol
        case rotatingText, counter, counterGoal, showCounterButtons, showTimerButton
        case pomoPhase, pomoStart, pomoEnd, daysSince, cryptoSymbol, cryptoPrice, cryptoChange, worldTZ
        case slideData, buttonKinds
        case minimalRing, clockMode, lockAlign, graphKind, spark, reactions, nextEventTitle, nextEventStart, netType, lowPower
        case uv, rainChance, wind, aqi, storageGB, volume, brightnessPct, stepsGoal, streak
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
    /// Placeholder date used for saved styles (live dates are filled in when the island updates).
    static let epoch = Date(timeIntervalSince1970: 0)

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
        lockLayout = c.value(.lockLayout, default: lockLayout)
        lockOwnText = c.value(.lockOwnText, default: lockOwnText)
        lockTitle = c.value(.lockTitle, default: lockTitle)
        lockSubtitle = c.value(.lockSubtitle, default: lockSubtitle)
        glow = c.value(.glow, default: glow)
        expandedChips = c.value(.expandedChips, default: expandedChips)
        expandedBar = c.value(.expandedBar, default: expandedBar)
        islandBg = c.value(.islandBg, default: islandBg)
        fontWeight = c.value(.fontWeight, default: fontWeight)
        fontWidth = c.value(.fontWidth, default: fontWidth)
        tracking = c.value(.tracking, default: tracking)
        glowStrength = c.value(.glowStrength, default: glowStrength)
        accentSync = c.value(.accentSync, default: accentSync)
        expandedLayout = c.value(.expandedLayout, default: expandedLayout)
        expandedTitleHex = c.value(.expandedTitleHex, default: expandedTitleHex)
        expandedIcon = c.value(.expandedIcon, default: expandedIcon)
        lockTitleHex = c.value(.lockTitleHex, default: lockTitleHex)
        lockIcon = c.value(.lockIcon, default: lockIcon)
        lockBgHex = c.value(.lockBgHex, default: lockBgHex)
        lockBg2Hex = c.value(.lockBg2Hex, default: lockBg2Hex)
        lockBarStyle = c.value(.lockBarStyle, default: lockBarStyle)
        badgeStyle = c.value(.badgeStyle, default: badgeStyle)
        chipKinds = c.value(.chipKinds, default: chipKinds)
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
        rotatingText = c.value(.rotatingText, default: rotatingText)
        counter = c.value(.counter, default: counter)
        counterGoal = c.value(.counterGoal, default: counterGoal)
        showCounterButtons = c.value(.showCounterButtons, default: showCounterButtons)
        showTimerButton = c.value(.showTimerButton, default: showTimerButton)
        pomoPhase = c.value(.pomoPhase, default: pomoPhase)
        pomoStart = c.value(.pomoStart, default: pomoStart)
        pomoEnd = c.value(.pomoEnd, default: pomoEnd)
        daysSince = c.value(.daysSince, default: daysSince)
        cryptoSymbol = c.value(.cryptoSymbol, default: cryptoSymbol)
        cryptoPrice = c.optional(.cryptoPrice)
        cryptoChange = c.optional(.cryptoChange)
        worldTZ = c.value(.worldTZ, default: worldTZ)
        slideData = c.optional(.slideData)
        buttonKinds = c.value(.buttonKinds, default: buttonKinds)
        minimalRing = c.value(.minimalRing, default: minimalRing)
        clockMode = c.value(.clockMode, default: clockMode)
        lockAlign = c.value(.lockAlign, default: lockAlign)
        graphKind = c.value(.graphKind, default: graphKind)
        spark = c.value(.spark, default: spark)
        reactions = c.value(.reactions, default: reactions)
        nextEventTitle = c.value(.nextEventTitle, default: nextEventTitle)
        nextEventStart = c.value(.nextEventStart, default: nextEventStart)
        netType = c.value(.netType, default: netType)
        lowPower = c.value(.lowPower, default: lowPower)
        uv = c.optional(.uv)
        rainChance = c.optional(.rainChance)
        wind = c.optional(.wind)
        aqi = c.optional(.aqi)
        storageGB = c.value(.storageGB, default: storageGB)
        volume = c.value(.volume, default: volume)
        brightnessPct = c.value(.brightnessPct, default: brightnessPct)
        stepsGoal = c.value(.stepsGoal, default: stepsGoal)
        streak = c.value(.streak, default: streak)
    }

    // Compact encoding: values left at their default aren't written, keeping the island under 4 KB.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let d = IslandState()
        try c.put(left, d.left, .left)
        try c.put(right, d.right, .right)
        try c.put(minimal, d.minimal, .minimal)
        try c.put(expandedTitle, d.expandedTitle, .expandedTitle)
        try c.put(expandedSubtitle, d.expandedSubtitle, .expandedSubtitle)
        try c.put(keylineHex, d.keylineHex, .keylineHex)
        try c.put(fontDesign, d.fontDesign, .fontDesign)
        try c.put(bold, d.bold, .bold)
        try c.encodeIfPresent(imageData, forKey: .imageData)
        try c.put(lockStyle, d.lockStyle, .lockStyle)
        try c.put(lockChips, d.lockChips, .lockChips)
        try c.put(lockAccent, d.lockAccent, .lockAccent)
        try c.put(lockLayout, d.lockLayout, .lockLayout)
        try c.put(lockOwnText, d.lockOwnText, .lockOwnText)
        try c.put(lockTitle, d.lockTitle, .lockTitle)
        try c.put(lockSubtitle, d.lockSubtitle, .lockSubtitle)
        try c.put(glow, d.glow, .glow)
        try c.put(expandedChips, d.expandedChips, .expandedChips)
        try c.put(expandedBar, d.expandedBar, .expandedBar)
        try c.put(islandBg, d.islandBg, .islandBg)
        try c.put(fontWeight, d.fontWeight, .fontWeight)
        try c.put(fontWidth, d.fontWidth, .fontWidth)
        try c.put(tracking, d.tracking, .tracking)
        try c.put(glowStrength, d.glowStrength, .glowStrength)
        try c.put(accentSync, d.accentSync, .accentSync)
        try c.put(expandedLayout, d.expandedLayout, .expandedLayout)
        try c.put(expandedTitleHex, d.expandedTitleHex, .expandedTitleHex)
        try c.put(expandedIcon, d.expandedIcon, .expandedIcon)
        try c.put(lockTitleHex, d.lockTitleHex, .lockTitleHex)
        try c.put(lockIcon, d.lockIcon, .lockIcon)
        try c.put(lockBgHex, d.lockBgHex, .lockBgHex)
        try c.put(lockBg2Hex, d.lockBg2Hex, .lockBg2Hex)
        try c.put(lockBarStyle, d.lockBarStyle, .lockBarStyle)
        try c.put(badgeStyle, d.badgeStyle, .badgeStyle)
        try c.put(chipKinds, d.chipKinds, .chipKinds)
        try c.put(frame, d.frame, .frame)
        try c.putDate(cycleStart, .cycleStart)
        try c.putDate(cycleEnd, .cycleEnd)
        try c.putDate(sessionStart, .sessionStart)
        try c.putDate(now, .now)
        try c.put(battery, d.battery, .battery)
        try c.put(charging, d.charging, .charging)
        try c.put(paused, d.paused, .paused)
        try c.put(showButtons, d.showButtons, .showButtons)
        try c.put(bannerText, d.bannerText, .bannerText)
        try c.putDate(countdownTarget, .countdownTarget)
        try c.put(musicTitle, d.musicTitle, .musicTitle)
        try c.put(musicArtist, d.musicArtist, .musicArtist)
        try c.put(musicPlaying, d.musicPlaying, .musicPlaying)
        try c.encodeIfPresent(musicArt, forKey: .musicArt)
        try c.put(steps, d.steps, .steps)
        try c.encodeIfPresent(weatherTemp, forKey: .weatherTemp)
        try c.put(weatherSymbol, d.weatherSymbol, .weatherSymbol)
        try c.put(rotatingText, d.rotatingText, .rotatingText)
        try c.put(counter, d.counter, .counter)
        try c.put(counterGoal, d.counterGoal, .counterGoal)
        try c.put(showCounterButtons, d.showCounterButtons, .showCounterButtons)
        try c.put(showTimerButton, d.showTimerButton, .showTimerButton)
        try c.put(pomoPhase, d.pomoPhase, .pomoPhase)
        try c.putDate(pomoStart, .pomoStart)
        try c.putDate(pomoEnd, .pomoEnd)
        try c.putDate(daysSince, .daysSince)
        try c.put(cryptoSymbol, d.cryptoSymbol, .cryptoSymbol)
        try c.encodeIfPresent(cryptoPrice, forKey: .cryptoPrice)
        try c.encodeIfPresent(cryptoChange, forKey: .cryptoChange)
        try c.put(worldTZ, d.worldTZ, .worldTZ)
        try c.encodeIfPresent(slideData, forKey: .slideData)
        try c.put(buttonKinds, d.buttonKinds, .buttonKinds)
        try c.put(minimalRing, d.minimalRing, .minimalRing)
        try c.put(clockMode, d.clockMode, .clockMode)
        try c.put(lockAlign, d.lockAlign, .lockAlign)
        try c.put(graphKind, d.graphKind, .graphKind)
        try c.put(spark, d.spark, .spark)
        try c.put(reactions, d.reactions, .reactions)
        try c.put(nextEventTitle, d.nextEventTitle, .nextEventTitle)
        if !nextEventTitle.isEmpty { try c.encode(nextEventStart, forKey: .nextEventStart) }
        try c.put(netType, d.netType, .netType)
        try c.put(lowPower, d.lowPower, .lowPower)
        try c.encodeIfPresent(uv, forKey: .uv)
        try c.encodeIfPresent(rainChance, forKey: .rainChance)
        try c.encodeIfPresent(wind, forKey: .wind)
        try c.encodeIfPresent(aqi, forKey: .aqi)
        try c.put(storageGB, d.storageGB, .storageGB)
        try c.put(volume, d.volume, .volume)
        try c.put(brightnessPct, d.brightnessPct, .brightnessPct)
        try c.put(stepsGoal, d.stepsGoal, .stepsGoal)
        try c.put(streak, d.streak, .streak)
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

    /// Drops the heaviest optional data until the state fits ActivityKit's 4 KB limit (with a safety margin).
    mutating func fitToBudget(limit: Int = 3500) {
        if encodedSize > limit { musicArt = nil }
        if encodedSize > limit { slideData = nil }
        if encodedSize > limit { imageData = nil }
        if encodedSize > limit { spark = [] }
        if encodedSize > limit {
            musicTitle = String(musicTitle.prefix(20))
            musicArtist = ""
            expandedSubtitle = String(expandedSubtitle.prefix(20))
            rotatingText = String(rotatingText.prefix(20))
            lockSubtitle = ""
        }
    }

    /// Lock Screen title: pop-out banner first, then its own text or the long-press text.
    var lockTitleText: String {
        if !bannerText.isEmpty { return bannerText }
        return TextVars.resolve(lockOwnText ? lockTitle : expandedTitle, state: self)
    }

    var lockSubtitleText: String {
        TextVars.resolve(lockOwnText ? lockSubtitle : expandedSubtitle, state: self)
    }

    var expandedTitleText: String { TextVars.resolve(expandedTitle, state: self) }

    var expandedSubtitleText: String { TextVars.resolve(expandedSubtitle, state: self) }

    /// Accent color without its alpha, for badges, bars and buttons.
    var accentColor: Color { Color(hex: String(keylineHex.prefix(6))) }

    var weightValue: Font.Weight {
        switch fontWeight {
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return bold ? .bold : .regular
        }
    }

    var widthValue: Font.Width {
        switch fontWidth {
        case "condensed": return .condensed
        case "compressed": return .compressed
        case "expanded": return .expanded
        default: return .standard
        }
    }

    /// Slot size in the long-press view.
    var expandedSlotSize: CGFloat {
        switch expandedLayout {
        case .standard: return 34
        case .centered: return 26
        case .big: return 44
        }
    }

    /// Solid tint behind the Lock Screen card (iOS only takes one color here).
    var lockBackground: Color {
        switch lockStyle {
        case .black: return Color.black.opacity(0.92)
        case .tinted: return accentColor.darker(0.25)
        case .glass: return Color.black.opacity(0.28)
        case .gradient: return accentColor.darker(0.3)
        case .custom: return Color(hex: lockBgHex)
        case .aurora: return accentColor.darker(0.3)
        }
    }

    /// Gradient drawn inside the Lock Screen card for the Gradient and Custom styles.
    var lockGradientColors: [Color]? {
        switch lockStyle {
        case .gradient:
            return [accentColor.darker(0.5), accentColor.hueShifted(0.15).darker(0.28)]
        case .custom:
            return [Color(hex: lockBgHex), Color(hex: lockBg2Hex)]
        default:
            return nil
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
        s.lockLayout = lockLayout
        s.lockOwnText = lockOwnText
        s.lockTitle = lockTitle
        s.lockSubtitle = lockSubtitle
        s.glow = glow
        s.expandedChips = expandedChips
        s.expandedBar = expandedBar
        s.islandBg = islandBg
        s.fontWeight = fontWeight
        s.fontWidth = fontWidth
        s.tracking = tracking
        s.glowStrength = glowStrength
        s.accentSync = accentSync
        s.expandedLayout = expandedLayout
        s.expandedTitleHex = expandedTitleHex
        s.expandedIcon = expandedIcon
        s.lockTitleHex = lockTitleHex
        s.lockIcon = lockIcon
        s.lockBgHex = lockBgHex
        s.lockBg2Hex = lockBg2Hex
        s.lockBarStyle = lockBarStyle
        s.badgeStyle = badgeStyle
        s.chipKinds = chipKinds
        s.minimalRing = minimalRing
        s.clockMode = clockMode
        s.lockAlign = lockAlign
        s.graphKind = graphKind
        // Fixed placeholder dates, so two copies of the same style compare equal.
        s.cycleStart = IslandState.epoch
        s.cycleEnd = IslandState.epoch
        s.sessionStart = IslandState.epoch
        s.now = IslandState.epoch
        s.countdownTarget = IslandState.epoch
        s.pomoStart = IslandState.epoch
        s.pomoEnd = IslandState.epoch
        s.daysSince = IslandState.epoch
        s.nextEventStart = IslandState.epoch
        return s
    }

    /// True when two styles look the same (ignoring the photo).
    func matchesStyle(_ other: IslandState) -> Bool {
        var a = styleOnly()
        var b = other.styleOnly()
        a.imageData = nil
        b.imageData = nil
        return a == b
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

extension KeyedEncodingContainer {
    /// Writes the value only when it differs from the default.
    mutating func put<T: Encodable & Equatable>(_ value: T, _ fallback: T, _ key: Key) throws {
        if value != fallback {
            try encode(value, forKey: key)
        }
    }

    /// Writes a date unless it's the saved-style placeholder.
    mutating func putDate(_ value: Date, _ key: Key) throws {
        if value != IslandState.epoch {
            try encode(value, forKey: key)
        }
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

    /// The last `width` letters, for text that types itself out.
    static func tail(_ text: String, width: Int) -> String {
        text.count <= width ? text : String(text.suffix(width))
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

    /// Rotates the hue, for gradients that stay in the same family.
    func hueShifted(_ delta: Double) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        var shifted = Double(h) + delta
        shifted -= floor(shifted)
        return Color(hue: shifted, saturation: Double(s), brightness: Double(b), opacity: Double(a))
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X%02X", c(r), c(g), c(b), c(a))
    }
}
