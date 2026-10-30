import Foundation

/// App-level settings that aren't part of a visual style (so presets don't overwrite them).
struct AppSettings: Codable, Hashable {
    var countdownTarget = Date().addingTimeInterval(7 * 86_400)
    var useFahrenheit = Locale.current.measurementSystem == .us
    var latitude: Double? = nil
    var longitude: Double? = nil
    var chargingMode = true
    var hourlyPopOut = false
    var chimeSound = false
    var showIslandButtons = true
    var currentPresetID = "neon"
    var schedule = ScheduleSettings()
    var musicMode: MusicMode = .keep
    var musicLeft = SlotConfig(content: .musicArt)
    var musicRight = SlotConfig(content: .musicBars, colorHex: "FF2D55FF")
    var musicLeftUsesMine = false
    var musicRightUsesMine = true
    var musicSongTitle = true

    enum CodingKeys: String, CodingKey {
        case countdownTarget, useFahrenheit, latitude, longitude, chargingMode
        case hourlyPopOut, chimeSound, showIslandButtons, currentPresetID, schedule, musicMode
        case musicLeft, musicRight, musicLeftUsesMine, musicRightUsesMine, musicSongTitle
    }
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        countdownTarget = c.value(.countdownTarget, default: countdownTarget)
        useFahrenheit = c.value(.useFahrenheit, default: useFahrenheit)
        latitude = c.optional(.latitude)
        longitude = c.optional(.longitude)
        chargingMode = c.value(.chargingMode, default: chargingMode)
        hourlyPopOut = c.value(.hourlyPopOut, default: hourlyPopOut)
        chimeSound = c.value(.chimeSound, default: chimeSound)
        showIslandButtons = c.value(.showIslandButtons, default: showIslandButtons)
        currentPresetID = c.value(.currentPresetID, default: currentPresetID)
        schedule = c.value(.schedule, default: schedule)
        musicMode = c.value(.musicMode, default: musicMode)
        musicLeft = c.value(.musicLeft, default: musicLeft)
        musicRight = c.value(.musicRight, default: musicRight)
        musicLeftUsesMine = c.value(.musicLeftUsesMine, default: musicLeftUsesMine)
        musicRightUsesMine = c.value(.musicRightUsesMine, default: musicRightUsesMine)
        musicSongTitle = c.value(.musicSongTitle, default: musicSongTitle)
    }
}

struct ScheduleSettings: Codable, Hashable {
    var enabled = false
    var blocks: [ScheduleBlock] = [
        ScheduleBlock(id: "morning", name: "Morning", startMinute: 6 * 60, presetID: "clean"),
        ScheduleBlock(id: "day", name: "Day", startMinute: 12 * 60, presetID: "neon"),
        ScheduleBlock(id: "night", name: "Night", startMinute: 20 * 60, presetID: "eq")
    ]
}

struct ScheduleBlock: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    /// Minutes after midnight.
    var startMinute: Int
    var presetID: String
}

/// What the island does while music (or other audio) is playing.
enum MusicMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case keep, showMusic, hide

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keep: return "Keep my island"
        case .showMusic: return "Show the music"
        case .hide: return "Let music take over"
        }
    }

    var explanation: String {
        switch self {
        case .keep:
            return "Your island stays as it is. iOS keeps it in the big spot and puts the music player in the small bubble."
        case .showMusic:
            return "While anything plays, the island shows your music layout: album art on one side and your own preset's minimal bubble on the other, then switches back when it stops. Song details come from Apple Music."
        case .hide:
            return "Your island steps aside so the music player gets the whole island, then comes back when the music stops. FaceTime and phone calls never trigger this."
        }
    }
}
