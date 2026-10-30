import Foundation

/// App-level settings that aren't part of a visual style (so presets don't overwrite them).
struct AppSettings: Codable, Hashable {
    var countdownTarget = Date().addingTimeInterval(7 * 86_400)
    var useFahrenheit = Locale.current.measurementSystem == .us
    var latitude: Double? = nil
    var longitude: Double? = nil
    var chargingMode = true
    var chargingTakeover = false
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

    // Alerts and automation
    var lowBatteryAlert = true
    var headphonesPopOut = true
    var holidayAuto = false
    var birthdayEnabled = false
    var birthday = Date()

    // Tools
    var counter = 0
    var counterGoal = 8
    var counterButtons = true
    var counterResetsDaily = true
    var counterDay = ""
    var focusMinutes = 25
    var breakMinutes = 5
    var pomoPhase = ""
    var pomoStart = Date()
    var pomoEnd = Date()
    var daysSince = Date().addingTimeInterval(-30 * 86_400)
    var cryptoCoin = "BTC"
    var worldTZ = "Asia/Tokyo"
    var messagesText = "You've got this\nDrink some water\nTake a deep breath"
    var messageSeconds = 4.0

    // Presets
    var defaultPresetID = "neon"
    var favoriteIDs: [String] = []

    // Rules and shuffle
    var rulesEnabled = false
    var rules: [IslandRule] = []
    var shuffleEnabled = false
    var shuffleMinutes = 30
    var shuffleSource = "all"

    // Controls and media
    var expandedButtons: [String] = ["prev", "pause", "next"]
    var slideshowPhotos: [Data] = []
    var slideSeconds = 3.0

    enum CodingKeys: String, CodingKey {
        case countdownTarget, useFahrenheit, latitude, longitude, chargingMode, chargingTakeover
        case hourlyPopOut, chimeSound, showIslandButtons, currentPresetID, schedule, musicMode
        case musicLeft, musicRight, musicLeftUsesMine, musicRightUsesMine, musicSongTitle
        case lowBatteryAlert, headphonesPopOut, holidayAuto, birthdayEnabled, birthday
        case counter, counterGoal, counterButtons, counterResetsDaily, counterDay
        case focusMinutes, breakMinutes, pomoPhase, pomoStart, pomoEnd
        case daysSince, cryptoCoin, worldTZ, messagesText, messageSeconds
        case defaultPresetID, favoriteIDs, rulesEnabled, rules, shuffleEnabled, shuffleMinutes, shuffleSource
        case expandedButtons, slideshowPhotos, slideSeconds
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
        chargingTakeover = c.value(.chargingTakeover, default: chargingTakeover)
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
        lowBatteryAlert = c.value(.lowBatteryAlert, default: lowBatteryAlert)
        headphonesPopOut = c.value(.headphonesPopOut, default: headphonesPopOut)
        holidayAuto = c.value(.holidayAuto, default: holidayAuto)
        birthdayEnabled = c.value(.birthdayEnabled, default: birthdayEnabled)
        birthday = c.value(.birthday, default: birthday)
        counter = c.value(.counter, default: counter)
        counterGoal = c.value(.counterGoal, default: counterGoal)
        counterButtons = c.value(.counterButtons, default: counterButtons)
        counterResetsDaily = c.value(.counterResetsDaily, default: counterResetsDaily)
        counterDay = c.value(.counterDay, default: counterDay)
        focusMinutes = c.value(.focusMinutes, default: focusMinutes)
        breakMinutes = c.value(.breakMinutes, default: breakMinutes)
        pomoPhase = c.value(.pomoPhase, default: pomoPhase)
        pomoStart = c.value(.pomoStart, default: pomoStart)
        pomoEnd = c.value(.pomoEnd, default: pomoEnd)
        daysSince = c.value(.daysSince, default: daysSince)
        cryptoCoin = c.value(.cryptoCoin, default: cryptoCoin)
        worldTZ = c.value(.worldTZ, default: worldTZ)
        messagesText = c.value(.messagesText, default: messagesText)
        messageSeconds = c.value(.messageSeconds, default: messageSeconds)
        defaultPresetID = c.value(.defaultPresetID, default: defaultPresetID)
        favoriteIDs = c.value(.favoriteIDs, default: favoriteIDs)
        rulesEnabled = c.value(.rulesEnabled, default: rulesEnabled)
        rules = c.value(.rules, default: rules)
        shuffleEnabled = c.value(.shuffleEnabled, default: shuffleEnabled)
        shuffleMinutes = c.value(.shuffleMinutes, default: shuffleMinutes)
        shuffleSource = c.value(.shuffleSource, default: shuffleSource)
        expandedButtons = c.value(.expandedButtons, default: expandedButtons)
        slideshowPhotos = c.value(.slideshowPhotos, default: slideshowPhotos)
        slideSeconds = c.value(.slideSeconds, default: slideSeconds)
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

// MARK: - Rules

/// "If this happens, show that preset." Rules swap the look temporarily and never change your saved style.
struct IslandRule: Codable, Hashable, Identifiable {
    var id = UUID().uuidString
    var enabled = true
    var kind: RuleKind = .batteryBelow
    var number = 20
    var startMinute = 22 * 60
    var endMinute = 6 * 60
    var presetID = "nightowl"
}

enum RuleKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case batteryBelow, charging, music, headphones, rain, snow, hot, cold, timeRange, weekend

    var id: String { rawValue }

    var label: String {
        switch self {
        case .batteryBelow: return "Battery is low"
        case .charging: return "Charging"
        case .music: return "Music is playing"
        case .headphones: return "Headphones connected"
        case .rain: return "It's raining"
        case .snow: return "It's snowing"
        case .hot: return "It's hot"
        case .cold: return "It's cold"
        case .timeRange: return "Time of day"
        case .weekend: return "Weekend"
        }
    }

    var icon: String {
        switch self {
        case .batteryBelow: return "battery.25"
        case .charging: return "bolt.fill"
        case .music: return "music.note"
        case .headphones: return "headphones"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .hot: return "thermometer.sun.fill"
        case .cold: return "thermometer.snowflake"
        case .timeRange: return "clock.fill"
        case .weekend: return "calendar"
        }
    }

    /// The label for the rule's number, when it has one.
    var numberLabel: String? {
        switch self {
        case .batteryBelow: return "At or below"
        case .hot: return "At or above"
        case .cold: return "At or below"
        default: return nil
        }
    }

    var numberRange: ClosedRange<Int> {
        switch self {
        case .batteryBelow: return 5...50
        case .hot: return 50...120
        case .cold: return -20...60
        default: return 0...100
        }
    }

    var numberUnit: String {
        self == .batteryBelow ? "%" : "°"
    }
}
