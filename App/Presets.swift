import Foundation

struct IslandPreset: Identifiable {
    let id: String
    let name: String
    let icon: String
    let build: () -> IslandState

    static let all: [IslandPreset] = [
        IslandPreset(id: "neon", name: "Neon Ring", icon: "circle.dashed") {
            var s = IslandState()
            s.left = SlotConfig(content: .ring, colorHex: "00E5FFFF")
            s.right = SlotConfig(content: .liveClock, colorHex: "00E5FFFF")
            s.minimal = SlotConfig(content: .ring, colorHex: "00E5FFFF")
            s.keylineHex = "00E5FFFF"
            return s
        },
        IslandPreset(id: "clean", name: "Clean", icon: "clock") {
            var s = IslandState()
            s.left = SlotConfig(content: .clock, colorHex: "FFFFFFFF")
            s.right = SlotConfig(content: .battery, colorHex: "34C759FF")
            s.minimal = SlotConfig(content: .battery, colorHex: "34C759FF")
            s.keylineHex = "FFFFFF40"
            s.bold = false
            return s
        },
        IslandPreset(id: "eq", name: "Equalizer", icon: "waveform") {
            var s = IslandState()
            s.left = SlotConfig(content: .equalizer, colorHex: "FF2D92FF")
            s.right = SlotConfig(content: .equalizer, colorHex: "AF52DEFF")
            s.minimal = SlotConfig(content: .equalizer, colorHex: "FF2D92FF")
            s.keylineHex = "FF2D92FF"
            return s
        },
        IslandPreset(id: "rainbow", name: "Rainbow", icon: "sparkles") {
            var s = IslandState()
            s.left = SlotConfig(content: .rainbow, symbol: "sparkles")
            s.right = SlotConfig(content: .spin, symbol: "star.fill", colorHex: "FFD60AFF")
            s.minimal = SlotConfig(content: .rainbow, symbol: "sparkles")
            s.keylineHex = "FFD60AFF"
            return s
        },
        IslandPreset(id: "fire", name: "Fire", icon: "flame.fill") {
            var s = IslandState()
            s.left = SlotConfig(content: .emoji, text: "🔥")
            s.right = SlotConfig(content: .bar, colorHex: "FF9500FF")
            s.minimal = SlotConfig(content: .pulse, symbol: "flame.fill", colorHex: "FF9500FF")
            s.keylineHex = "FF3B30FF"
            return s
        },
        IslandPreset(id: "date", name: "Date + Timer", icon: "calendar") {
            var s = IslandState()
            s.left = SlotConfig(content: .date, colorHex: "FFFFFFFF")
            s.right = SlotConfig(content: .timer, colorHex: "0A84FFFF")
            s.minimal = SlotConfig(content: .symbol, symbol: "calendar", colorHex: "0A84FFFF")
            s.keylineHex = "0A84FFFF"
            return s
        }
    ]
}
