import Foundation

struct SavedPreset: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var icon: String
    var style: IslandState
}

/// Built-in presets plus the user's saved ones (stored in UserDefaults).
enum PresetStore {
    private static let customKey = "savedPresets"
    private static let codePrefix = "ISL1:"

    static let builtIns: [SavedPreset] = [
        make("neon", "Neon Ring", "circle.dashed") { (s: inout IslandState) in
            s.left = SlotConfig(content: .ring, colorHex: "00E5FFFF")
            s.right = SlotConfig(content: .liveClock, colorHex: "00E5FFFF")
            s.minimal = SlotConfig(content: .ring, colorHex: "00E5FFFF")
            s.keylineHex = "00E5FFFF"
        },
        make("clean", "Clean", "clock") { (s: inout IslandState) in
            s.left = SlotConfig(content: .clock, colorHex: "FFFFFFFF")
            s.right = SlotConfig(content: .battery, colorHex: "34C759FF")
            s.minimal = SlotConfig(content: .battery, colorHex: "34C759FF")
            s.keylineHex = "FFFFFF40"
            s.bold = false
        },
        make("music", "Music", "music.note") { (s: inout IslandState) in
            s.left = SlotConfig(content: .musicArt)
            s.right = SlotConfig(content: .musicBars, colorHex: "FF2D55FF")
            s.minimal = SlotConfig(content: .musicBars, colorHex: "FF2D55FF")
            s.expandedTitle = "Now Playing"
            s.expandedSubtitle = ""
            s.keylineHex = "FF2D55FF"
        },
        make("weather", "Weather", "cloud.sun.fill") { (s: inout IslandState) in
            s.left = SlotConfig(content: .weather, colorHex: "FFD60AFF")
            s.right = SlotConfig(content: .steps, colorHex: "30D158FF")
            s.minimal = SlotConfig(content: .weather, colorHex: "FFD60AFF")
            s.keylineHex = "64D2FFFF"
        },
        make("countdown", "Countdown", "hourglass") { (s: inout IslandState) in
            s.left = SlotConfig(content: .countdown, text: "🎉", colorHex: "FFFFFFFF")
            s.right = SlotConfig(content: .date, colorHex: "FFD60AFF")
            s.minimal = SlotConfig(content: .symbol, symbol: "hourglass", colorHex: "FFD60AFF")
            s.keylineHex = "FFD60AFF"
        },
        make("ticker", "Ticker", "text.alignleft") { (s: inout IslandState) in
            s.left = SlotConfig(content: .marquee, text: "Welcome to Island Studio", colorHex: "00E5FFFF",
                                color2Hex: "5E5CE6FF", colorMode: .gradient)
            s.right = SlotConfig(content: .ring, colorHex: "5E5CE6FF")
            s.minimal = SlotConfig(content: .pulse, symbol: "circle.fill", colorHex: "5E5CE6FF")
            s.keylineHex = "5E5CE6FF"
        },
        make("sunset", "Sunset", "sun.horizon.fill") { (s: inout IslandState) in
            s.left = SlotConfig(content: .symbol, symbol: "sun.horizon.fill", colorHex: "FF9500FF",
                                color2Hex: "FF2D55FF", colorMode: .gradient)
            s.right = SlotConfig(content: .clock, colorHex: "FF9500FF", color2Hex: "FF2D55FF", colorMode: .gradient)
            s.minimal = SlotConfig(content: .symbol, symbol: "sun.horizon.fill", colorHex: "FF9500FF",
                                   color2Hex: "FF2D55FF", colorMode: .gradient)
            s.keylineHex = "FF9500FF"
        },
        make("disco", "Disco", "circle.hexagongrid.fill") { (s: inout IslandState) in
            s.left = SlotConfig(content: .pulse, symbol: "circle.fill", colorHex: "00E5FFFF",
                                color2Hex: "FF2D92FF", colorMode: .cycle)
            s.right = SlotConfig(content: .equalizer, colorHex: "FF2D92FF", color2Hex: "00E5FFFF", colorMode: .cycle)
            s.minimal = SlotConfig(content: .pulse, symbol: "circle.fill", colorHex: "00E5FFFF",
                                   color2Hex: "FF2D92FF", colorMode: .cycle)
            s.keylineHex = "AF52DEFF"
        },
        make("eq", "Equalizer", "waveform") { (s: inout IslandState) in
            s.left = SlotConfig(content: .equalizer, colorHex: "FF2D92FF")
            s.right = SlotConfig(content: .equalizer, colorHex: "AF52DEFF")
            s.minimal = SlotConfig(content: .equalizer, colorHex: "FF2D92FF")
            s.keylineHex = "FF2D92FF"
        },
        make("rainbow", "Rainbow", "sparkles") { (s: inout IslandState) in
            s.left = SlotConfig(content: .rainbow, symbol: "sparkles")
            s.right = SlotConfig(content: .spin, symbol: "star.fill", colorHex: "FFD60AFF")
            s.minimal = SlotConfig(content: .rainbow, symbol: "sparkles")
            s.keylineHex = "FFD60AFF"
        },
        make("fire", "Fire", "flame.fill") { (s: inout IslandState) in
            s.left = SlotConfig(content: .emoji, text: "🔥")
            s.right = SlotConfig(content: .bar, colorHex: "FF9500FF")
            s.minimal = SlotConfig(content: .pulse, symbol: "flame.fill", colorHex: "FF9500FF")
            s.keylineHex = "FF3B30FF"
        },
        make("date", "Date + Timer", "calendar") { (s: inout IslandState) in
            s.left = SlotConfig(content: .date, colorHex: "FFFFFFFF")
            s.right = SlotConfig(content: .timer, colorHex: "0A84FFFF")
            s.minimal = SlotConfig(content: .symbol, symbol: "calendar", colorHex: "0A84FFFF")
            s.keylineHex = "0A84FFFF"
        }
    ]

    private static func make(_ id: String, _ name: String, _ icon: String,
                             _ configure: (inout IslandState) -> Void) -> SavedPreset {
        var s = IslandState()
        configure(&s)
        return SavedPreset(id: id, name: name, icon: icon, style: s.styleOnly())
    }

    static func loadCustom() -> [SavedPreset] {
        guard let data = UserDefaults.standard.data(forKey: customKey),
              let list = try? JSONDecoder().decode([SavedPreset].self, from: data) else { return [] }
        return list
    }

    static func saveCustom(_ list: [SavedPreset]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: customKey)
        }
    }

    static func all() -> [SavedPreset] {
        builtIns + loadCustom()
    }

    static func find(_ id: String) -> SavedPreset? {
        all().first { $0.id == id }
    }

    // MARK: Share codes

    static func exportCode(_ preset: SavedPreset) -> String {
        var p = preset
        p.style = preset.style.styleOnly()
        guard let data = try? JSONEncoder().encode(p) else { return "" }
        return codePrefix + data.base64EncodedString()
    }

    static func importCode(_ text: String) -> SavedPreset? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(codePrefix),
              let data = Data(base64Encoded: String(trimmed.dropFirst(codePrefix.count))),
              var preset = try? JSONDecoder().decode(SavedPreset.self, from: data) else { return nil }
        preset.id = UUID().uuidString
        return preset
    }
}
