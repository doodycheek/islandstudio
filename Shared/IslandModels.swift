import ActivityKit
import SwiftUI
import UIKit

struct IslandAttributes: ActivityAttributes {
    public typealias ContentState = IslandState
    var name: String
}

enum SlotContent: String, Codable, CaseIterable, Identifiable, Hashable {
    case empty, text, emoji, symbol, image, clock, liveClock, date, battery
    case ring, bar, timer, pulse, equalizer, spin, rainbow

    var id: String { rawValue }

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
        case .ring: return "✨ Looping ring"
        case .bar: return "✨ Looping bar"
        case .timer: return "✨ Running timer"
        case .pulse: return "✨ Pulse"
        case .equalizer: return "✨ Equalizer"
        case .spin: return "✨ Spin"
        case .rainbow: return "✨ Rainbow"
        }
    }

    var usesText: Bool { self == .text || self == .emoji }
    var usesSymbol: Bool { self == .symbol || self == .pulse || self == .spin || self == .rainbow }
    var usesColor: Bool { !(self == .empty || self == .emoji || self == .image || self == .rainbow) }
}

struct SlotConfig: Codable, Hashable {
    var content: SlotContent = .empty
    var text: String = ""
    var symbol: String = "star.fill"
    var colorHex: String = "FFFFFFFF"
}

/// Everything the island needs. ActivityKit caps this at 4 KB total, so keep it lean.
struct IslandState: Codable, Hashable {
    // Editable style
    var left = SlotConfig(content: .ring, colorHex: "00E5FFFF")
    var right = SlotConfig(content: .battery, colorHex: "34C759FF")
    var minimal = SlotConfig(content: .pulse, symbol: "circle.fill", colorHex: "00E5FFFF")
    var expandedTitle = "Island Studio"
    var expandedSubtitle = "Your island, your rules"
    var keylineHex = "00E5FFFF"
    var fontDesign = "rounded"
    var bold = true
    var imageData: Data? = nil

    // Live values the background loop keeps refreshing
    var frame = 0
    var cycleStart = Date()
    var cycleEnd = Date().addingTimeInterval(3)
    var sessionStart = Date()
    var now = Date()
    var battery = -1
    var charging = false

    var design: Font.Design {
        switch fontDesign {
        case "rounded": return .rounded
        case "monospaced": return .monospaced
        case "serif": return .serif
        default: return .default
        }
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

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X%02X", c(r), c(g), c(b), c(a))
    }
}
