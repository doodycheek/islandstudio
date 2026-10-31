import ActivityKit
import AVFoundation
import CallKit
import CoreMotion
import SwiftUI
import UIKit
import UserNotifications

/// Everything the Backup button saves and restores.
struct BackupData: Codable {
    var config: IslandState
    var settings: AppSettings
    var presets: [SavedPreset]
    var speed: Double? = nil
    var loop: Double? = nil
    var keepAlive: Bool? = nil
}

@MainActor
final class IslandManager: ObservableObject {
    static let shared = IslandManager()

    // MARK: - Published state

    @Published var config: IslandState {
        didSet {
            recordUndo(previous: oldValue)
            saveConfig()
            scheduleAutoSave()
            configChanged()
        }
    }

    @Published var settings: AppSettings {
        didSet {
            if oldValue.schedule != settings.schedule {
                lastScheduleKey = ""
            }
            if oldValue.useFahrenheit != settings.useFahrenheit
                || oldValue.latitude != settings.latitude
                || oldValue.longitude != settings.longitude {
                lastWeatherFetch = nil
            }
            if oldValue.shuffleEnabled != settings.shuffleEnabled
                || oldValue.shuffleMinutes != settings.shuffleMinutes
                || oldValue.shuffleSource != settings.shuffleSource {
                lastShuffle = nil
            }
            if oldValue.cryptoCoin != settings.cryptoCoin {
                lastCryptoFetch = nil
                info.cryptoPrice = nil
                info.cryptoChange = nil
            }
            UserDefaults.standard.set(settings.haptics, forKey: "hapticsOn")
            saveSettings()
            scheduleAutoSave()
            configChanged()
        }
    }

    @Published var keepAlive: Bool {
        didSet {
            UserDefaults.standard.set(keepAlive, forKey: Keys.keepAlive)
            applyKeepAlive()
        }
    }

    /// Seconds between animation frames sent to the island.
    @Published var frameInterval: Double {
        didSet { UserDefaults.standard.set(frameInterval, forKey: Keys.frameInterval) }
    }

    /// Seconds for one sweep of the looping ring / bar.
    @Published var cycleLength: Double {
        didSet { UserDefaults.standard.set(cycleLength, forKey: Keys.cycleLength) }
    }

    @Published var savedPresets: [SavedPreset] {
        didSet {
            PresetStore.saveCustom(savedPresets)
            scheduleAutoSave()
        }
    }

    @Published var paused = false {
        didSet { configChanged() }
    }

    /// Short message shown in the preview header. Clears itself after a few seconds.
    @Published var status = "" {
        didSet {
            guard !status.isEmpty else { return }
            statusClearTask?.cancel()
            let shown = status
            statusClearTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard let self, !Task.isCancelled, self.status == shown else { return }
                self.status = ""
            }
        }
    }

    @Published private(set) var isRunning = false
    @Published private(set) var isHiddenForMusic = false
    @Published private(set) var musicActive = false
    @Published private(set) var info = LiveInfo()
    /// What's temporarily overriding your style (a rule or shuffle), shown in the preview header.
    @Published private(set) var takeoverLabel = ""

    // MARK: - Private state

    private var activity: Activity<IslandAttributes>?
    private var loopTask: Task<Void, Never>?
    private var statusClearTask: Task<Void, Never>?
    private var activityStart = Date()
    private var cycleStart = Date()
    private var frame = 0
    private var waitingForForeground = false
    private var wasCharging = false
    private var lastChimeHour = -1
    private var bannerText = ""
    private var bannerUntil: Date?
    private var pendingBanner: String?
    private var lastPush = Date.distantPast
    private var lastScheduleKey = ""
    private var lastHolidayKey = ""
    private var lastStepsFetch: Date?
    private var lastWeatherFetch: Date?
    private var lastCryptoFetch: Date?
    private var stepsInFlight = false
    private var weatherInFlight = false
    private var cryptoInFlight = false
    private var triedAutoLocation = false
    private var musicSeenSince: Date?
    private var musicGoneSince: Date?
    private var lowNotified = 100
    private var takeoverStyle: IslandState?
    private var shuffleStyle: IslandState?
    private var shuffleName = ""
    private var lastShuffle: Date?
    private var albumAccentHex: String?
    private var lastHolidayPresetID = ""
    private let networkWatcher = NetworkWatcher()
    private let calendarWatcher = CalendarWatcher()
    private var lastCalendarFetch: Date?
    private var lastExtrasFetch: Date?
    private var lastAQIFetch: Date?
    private var lastStorageFetch: Date?
    private var lastHistorySample: Date?
    private var extrasInFlight = false
    private var aqiInFlight = false
    private var batteryHistory: [Int] = []
    private var stepsHistory: [Int] = []
    private var historyDay = ""
    private var undoStack: [IslandState] = []
    private var redoStack: [IslandState] = []
    private var lastUndoPush = Date.distantPast
    private var applyingHistory = false
    private var baseline = IslandState()
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    /// While true, the preview shows how your style looked before you started editing.
    @Published var comparing = false
    /// True while the island is being started, so the app can show a loading state.
    @Published private(set) var isStarting = false
    /// When your setup was last copied to the Keychain, and whether that worked.
    @Published private(set) var lastAutoSave: Date?
    @Published private(set) var autoSaveOK: Bool?
    /// True when this launch brought your setup back from the Keychain after a fresh install.
    @Published private(set) var restoredFromKeychain = false
    private var autoSaveTask: Task<Void, Never>?
    private var stoppedByUser = false

    private let musicWatcher = MusicWatcher()
    private let stepsWatcher = StepsWatcher()
    private let locationFetcher = LocationFetcher()
    private let callObserver = CXCallObserver()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private enum Keys {
        static let config = "islandConfig"
        static let settings = "appSettings"
        static let keepAlive = "keepAlive"
        static let frameInterval = "frameInterval"
        static let cycleLength = "cycleLength"
        static let wantsRunning = "wantsRunning"
        static let scheduleKey = "lastScheduleKey"
        static let holidayKey = "lastHolidayKey"
        static let holidayPresetKey = "lastHolidayPresetID"
    }

    private init() {
        let d = UserDefaults.standard
        // A fresh install has no saved data. If the Keychain still has your setup, bring it back.
        let fresh = d.data(forKey: Keys.config) == nil && d.data(forKey: Keys.settings) == nil
        let restored: BackupData? = fresh ? KeychainBackup.loadBackup() : nil
        config = restored?.config ?? Self.load(IslandState.self, key: Keys.config) ?? IslandState()
        settings = restored?.settings ?? Self.load(AppSettings.self, key: Keys.settings) ?? AppSettings()
        savedPresets = restored?.presets ?? PresetStore.loadCustom()
        keepAlive = d.object(forKey: Keys.keepAlive) as? Bool ?? true
        let fi = d.double(forKey: Keys.frameInterval)
        frameInterval = fi > 0 ? fi : 1.0
        let cl = d.double(forKey: Keys.cycleLength)
        cycleLength = cl > 0 ? cl : 3.0
        lastScheduleKey = d.string(forKey: Keys.scheduleKey) ?? ""
        lastHolidayKey = d.string(forKey: Keys.holidayKey) ?? ""
        lastHolidayPresetID = d.string(forKey: Keys.holidayPresetKey) ?? ""
        batteryHistory = d.array(forKey: "batteryHistory") as? [Int] ?? []
        stepsHistory = d.array(forKey: "stepsHistory") as? [Int] ?? []
        historyDay = d.string(forKey: "historyDay") ?? ""
        d.set(settings.haptics, forKey: "hapticsOn")
        baseline = config
        if restored != nil {
            saveConfig()
            saveSettings()
            PresetStore.saveCustom(savedPresets)
            if let value = restored?.speed { frameInterval = value; d.set(value, forKey: Keys.frameInterval) }
            if let value = restored?.loop { cycleLength = value; d.set(value, forKey: Keys.cycleLength) }
            if let value = restored?.keepAlive { keepAlive = value; d.set(value, forKey: Keys.keepAlive) }
            restoredFromKeychain = true
        }
        UIDevice.current.isBatteryMonitoringEnabled = true
        wasCharging = batteryInfo().charging
        reattach()
        startLoop()

        // Headphones / Bluetooth connecting.
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification,
                                               object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in self?.routeChanged(reasonRaw: raw) }
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Start / stop

    func start() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Live Activities are off: Settings → Island Studio → Live Activities"
            return
        }
        isStarting = true
        defer { isStarting = false }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        await endAllActivities()
        isHiddenForMusic = false
        activityStart = Date()
        cycleStart = activityStart
        frame = 0
        wasCharging = batteryInfo().charging
        do {
            activity = try Activity.request(
                attributes: IslandAttributes(name: "Island"),
                content: ActivityContent(state: liveState(), staleDate: nil),
                pushType: nil)
            isRunning = true
            waitingForForeground = false
            lastPush = Date()
            UserDefaults.standard.set(true, forKey: Keys.wantsRunning)
            stoppedByUser = false
            status = "Island is live. Swipe home to see it."
            applyKeepAlive()
        } catch {
            status = "Couldn't start: \(error.localizedDescription)"
        }
    }

    func stop() async {
        await endAllActivities()
        isRunning = false
        isHiddenForMusic = false
        UserDefaults.standard.set(false, forKey: Keys.wantsRunning)
        stoppedByUser = true
        applyKeepAlive()
        status = "Island stopped"
    }

    func appBecameActive() {
        let shouldRun = UserDefaults.standard.bool(forKey: Keys.wantsRunning) || (settings.autoStart && !stoppedByUser)
        guard shouldRun, !isHiddenForMusic else { return }
        let alive = activity.map { $0.activityState == .active } ?? false
        if !alive || waitingForForeground {
            Task { await start() }
        }
    }

    // MARK: - Presets

    func apply(_ preset: SavedPreset) {
        var s = preset.style
        if s.imageData == nil { s.imageData = config.imageData }
        settings.currentPresetID = preset.id
        config = s
        baseline = s
        Haptics.tap()
    }

    func applyPreset(id: String) {
        if let preset = PresetStore.find(id) { apply(preset) }
    }

    func stepPreset(by delta: Int) {
        let all = allPresets
        guard !all.isEmpty else { return }
        let next: Int
        if let index = all.firstIndex(where: { $0.id == settings.currentPresetID }) {
            next = ((index + delta) % all.count + all.count) % all.count
        } else {
            next = delta >= 0 ? 0 : all.count - 1
        }
        apply(all[next])
    }

    func saveCurrentAsPreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let preset = SavedPreset(id: UUID().uuidString,
                                 name: trimmed.isEmpty ? "My preset" : trimmed,
                                 icon: "star.square.fill",
                                 style: config.styleOnly())
        savedPresets.append(preset)
        placeNewPreset(preset.id)
        settings.currentPresetID = preset.id
        baseline = config
        Haptics.success()
        status = "Saved \(preset.name)"
    }

    func renamePreset(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isLocked(id) else { status = "Unlock it first to rename it"; return }
        guard !trimmed.isEmpty, let i = savedPresets.firstIndex(where: { $0.id == id }) else { return }
        savedPresets[i].name = trimmed
    }

    func deletePreset(id: String) {
        guard !isLocked(id) else { status = "Unlock it first to delete it"; return }
        savedPresets.removeAll { $0.id == id }
        var s = settings
        if s.defaultPresetID == id { s.defaultPresetID = "neon" }
        s.favoriteIDs.removeAll { $0 == id }
        s.presetOrder.removeAll { $0 == id }
        s.lockedIDs.removeAll { $0 == id }
        settings = s
    }

    /// Every preset, built-in first.
    /// Every preset in the order you arranged them. Until you arrange them, yours come first (newest on top).
    var allPresets: [SavedPreset] {
        let base = PresetStore.builtIns + savedPresets
        let order = settings.presetOrder
        if order.isEmpty {
            return settings.newPresetsFirst ? Array(savedPresets.reversed()) + PresetStore.builtIns : base
        }
        var rank: [String: Int] = [:]
        for (index, id) in order.enumerated() where rank[id] == nil { rank[id] = index }
        let listed = base.filter { rank[$0.id] != nil }.sorted { (rank[$0.id] ?? 0) < (rank[$1.id] ?? 0) }
        let rest = base.filter { rank[$0.id] == nil }
        return listed + rest
    }

    private func findPreset(_ id: String) -> SavedPreset? {
        allPresets.first { $0.id == id }
    }

    var currentPreset: SavedPreset? { findPreset(settings.currentPresetID) }

    /// True when you've edited a saved preset of yours and haven't saved the changes.
    var hasUnsavedChanges: Bool {
        guard let preset = savedPresets.first(where: { $0.id == settings.currentPresetID }) else { return false }
        return !config.matchesStyle(preset.style)
    }

    func isFavorite(_ id: String) -> Bool { settings.favoriteIDs.contains(id) }

    func toggleFavorite(_ id: String) {
        if let index = settings.favoriteIDs.firstIndex(of: id) {
            settings.favoriteIDs.remove(at: index)
        } else {
            settings.favoriteIDs.append(id)
        }
    }

    func setDefault(_ preset: SavedPreset) {
        settings.defaultPresetID = preset.id
        status = "\(preset.name) is now your default"
    }

    func applyDefault() {
        if let preset = findPreset(settings.defaultPresetID) {
            apply(preset)
            status = "Back to \(preset.name)"
        }
    }

    func updatePreset(id: String) {
        guard !isLocked(id) else { status = "That preset is locked. Unlock it to change it."; return }
        guard let index = savedPresets.firstIndex(where: { $0.id == id }) else { return }
        savedPresets[index].style = config.styleOnly()
        status = "Updated \(savedPresets[index].name)"
    }

    func duplicatePreset(_ preset: SavedPreset) {
        let copy = SavedPreset(id: UUID().uuidString, name: "\(preset.name) copy", icon: "star.square.fill",
                               style: preset.style.styleOnly())
        savedPresets.append(copy)
        placeNewPreset(copy.id)
        status = "Duplicated \(preset.name)"
    }

    /// Applies a random preset (different from the current one).
    func surprise() {
        let pool = allPresets.filter { $0.id != settings.currentPresetID }
        if let pick = pool.randomElement() {
            apply(pick)
            status = "Surprise: \(pick.name)"
        }
    }

    // MARK: - Colors

    func applyPalette(_ palette: ColorPalette) {
        var c = config
        c.keylineHex = palette.color(0)
        c.left.colorHex = palette.color(1)
        c.right.colorHex = palette.color(2)
        c.minimal.colorHex = palette.color(1)
        c.left.color2Hex = palette.color(3)
        c.right.color2Hex = palette.color(3)
        c.minimal.color2Hex = palette.color(3)
        config = c
        status = "Applied \(palette.name) colors"
    }

    var slotsFollowAccent: Bool {
        config.left.useAccent && config.right.useAccent && config.minimal.useAccent
    }

    func setSlotsFollowAccent(_ on: Bool) {
        var c = config
        c.left.useAccent = on
        c.right.useAccent = on
        c.minimal.useAccent = on
        config = c
    }

    func setSlideshowPhotos(_ photos: [Data]) {
        settings.slideshowPhotos = Array(photos.prefix(4))
        status = photos.isEmpty ? "Slideshow cleared" : "Slideshow has \(min(photos.count, 4)) photos"
    }

    func copyShareCode(_ preset: SavedPreset) {
        UIPasteboard.general.string = PresetStore.exportCode(preset)
        status = "Share code for \(preset.name) copied"
    }

    func importPresetFromClipboard() {
        guard let text = UIPasteboard.general.string, let preset = PresetStore.importCode(text) else {
            status = "No preset code found on the clipboard"
            return
        }
        savedPresets.append(preset)
        placeNewPreset(preset.id)
        status = "Added \(preset.name)"
    }

    // MARK: - Backup

    func copyBackup() {
        var exported = settings
        exported.latitude = nil
        exported.longitude = nil
        let backup = BackupData(config: config.styleOnly(), settings: exported, presets: savedPresets,
                                  speed: frameInterval, loop: cycleLength, keepAlive: keepAlive)
        guard let json = try? JSONEncoder().encode(backup) else {
            status = "Couldn't create a backup"
            return
        }
        UIPasteboard.general.string = "ISB1:" + json.base64EncodedString()
        status = "Backup copied to the clipboard"
    }

    func restoreBackupFromClipboard() {
        let text = (UIPasteboard.general.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("ISB1:"),
              let data = Data(base64Encoded: String(text.dropFirst(5))),
              let backup = try? JSONDecoder().decode(BackupData.self, from: data) else {
            status = "No backup code on the clipboard"
            return
        }
        var restored = backup.settings
        restored.latitude = settings.latitude
        restored.longitude = settings.longitude
        config = backup.config
        settings = restored
        savedPresets = backup.presets
        if let value = backup.speed { frameInterval = value }
        if let value = backup.loop { cycleLength = value }
        if let value = backup.keepAlive { keepAlive = value }
        status = "Backup restored"
    }

    // MARK: - Commands from island buttons and Shortcuts

    func handle(_ command: IslandCommand) async {
        switch command {
        case .next: stepPreset(by: 1)
        case .previous: stepPreset(by: -1)
        case .togglePause: paused.toggle()
        case .counterUp:
            settings.counter += 1
            if settings.counterGoal > 0 && settings.counter == settings.counterGoal {
                queueBanner("Goal reached 🎉")
            }
        case .counterDown:
            settings.counter = max(0, settings.counter - 1)
        case .counterReset:
            settings.counter = 0
        case .togglePomodoro:
            togglePomodoro()
        case .musicPlayPause:
            MusicWatcher.togglePlayPause()
        case .musicNext:
            MusicWatcher.next()
        case .musicPrevious:
            MusicWatcher.previous()
        case .surprise:
            surprise()
        case .react(let emoji):
            await popOutNow(emoji)
        }
        await pushUpdate()
    }

    func togglePomodoro() {
        if settings.pomoPhase.isEmpty {
            startPhase("focus", minutes: settings.focusMinutes, now: Date())
            status = "Focus started"
        } else {
            settings.pomoPhase = ""
            status = "Timer stopped"
        }
    }

    private func startPhase(_ phase: String, minutes: Int, now: Date) {
        var s = settings
        s.pomoPhase = phase
        s.pomoStart = now
        s.pomoEnd = now.addingTimeInterval(Double(max(1, minutes)) * 60)
        settings = s
    }

    // MARK: - Live info actions

    func updateLocation() async {
        status = "Getting your location…"
        if let location = await locationFetcher.current() {
            var s = settings
            s.latitude = location.coordinate.latitude
            s.longitude = location.coordinate.longitude
            settings = s
            status = "Location saved for weather"
        } else {
            status = "Couldn't get location. Check Settings → Island Studio → Location."
        }
    }

    func refreshWeatherNow() {
        lastWeatherFetch = nil
        status = "Refreshing weather…"
    }

    func requestMusicAccess() {
        Task {
            let granted = await MusicWatcher.requestAccess()
            self.status = granted ? "Music access is on" : "Music access is off. Turn it on in Settings → Island Studio."
        }
    }

    func refreshStepsNow() {
        Task {
            if let count = await self.stepsWatcher.todaySteps() {
                self.info.steps = count
                self.status = "Steps updated"
            } else {
                self.status = "Steps unavailable. Check Settings → Privacy → Motion & Fitness."
            }
        }
    }

    func testPopOut() async {
        guard isRunning, !isHiddenForMusic else {
            status = "Start the island first"
            return
        }
        status = "Pop-out in 5 seconds. Swipe home now!"
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        guard let current = activity, current.activityState == .active else { return }
        let text = Date().formatted(date: .omitted, time: .shortened)
        setBanner(text, now: Date())
        await current.update(ActivityContent(state: liveState(), staleDate: nil), alertConfiguration: makeAlert(text))
        lastPush = Date()
    }

    // MARK: - Previews

    /// What your chosen style looks like right now, animated. Previews never apply
    /// temporary takeovers (like charging), so you always see the style you're editing.
    /// `music: true` shows the music layout instead.
    func previewState(at date: Date, music: Bool = false) -> IslandState {
        let step = max(0.5, frameInterval)
        let length = max(1, cycleLength)
        let start = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / length) * length)
        let previewFrame = paused ? frame : Int(date.timeIntervalSince1970 / step)
        return compose(base: comparing ? baseline : config, now: date, frame: previewFrame, cycleStart: start, cycleLength: length,
                       sessionStart: isRunning ? activityStart : date, budget: false, live: false, forceMusic: music)
    }

    /// A still snapshot of any style, for preset tiles.
    func previewState(style: IslandState, at date: Date) -> IslandState {
        compose(base: style, now: date, frame: 0, cycleStart: date.addingTimeInterval(-1), cycleLength: 3,
                sessionStart: date, budget: false, live: false, forceMusic: false)
    }

    // MARK: - Internals

    private func reattach() {
        guard let existing = Activity<IslandAttributes>.activities.first(where: { $0.activityState == .active }) else { return }
        activity = existing
        activityStart = existing.content.state.sessionStart
        isRunning = true
        applyKeepAlive()
    }

    private func applyKeepAlive() {
        if keepAlive && isRunning {
            KeepAlive.shared.start()
        } else {
            KeepAlive.shared.stop()
        }
    }

    /// Uses the exact reader (every percent) and falls back to iOS's 5% steps.
    private func batteryInfo() -> (level: Int, charging: Bool) {
        let reading = BatteryReader.read()
        return (reading.level, reading.charging)
    }

    private func compose(base: IslandState, now: Date, frame: Int, cycleStart: Date, cycleLength: Double,
                         sessionStart: Date, budget: Bool, live: Bool, forceMusic: Bool) -> IslandState {
        var s = base
        let battery = batteryInfo()

        // Live values
        s.frame = frame
        s.cycleStart = cycleStart
        s.cycleEnd = cycleStart.addingTimeInterval(cycleLength)
        s.sessionStart = sessionStart
        s.now = now
        s.battery = battery.level
        s.charging = battery.charging
        s.paused = paused
        s.showButtons = settings.showIslandButtons
        s.bannerText = bannerText
        s.countdownTarget = settings.countdownTarget
        s.musicTitle = String(info.musicTitle.prefix(40))
        s.musicArtist = String(info.musicArtist.prefix(30))
        s.musicPlaying = info.musicPlaying || musicActive || forceMusic
        if forceMusic && s.musicTitle.isEmpty {
            s.musicTitle = "Song title"
            s.musicArtist = "Artist"
        }
        s.expandedTitle = String(s.expandedTitle.prefix(40))
        s.expandedSubtitle = String(s.expandedSubtitle.prefix(40))
        if s.lockOwnText {
            s.lockTitle = String(s.lockTitle.prefix(30))
            s.lockSubtitle = String(s.lockSubtitle.prefix(30))
        } else {
            s.lockTitle = ""
            s.lockSubtitle = ""
        }
        s.steps = info.steps
        s.weatherTemp = info.weatherTemp
        s.weatherSymbol = info.weatherSymbol

        // Temporary takeovers (real island only, except the music preview)
        if forceMusic || (live && settings.musicMode == .showMusic && musicActive) {
            applyMusicLayout(to: &s)
        } else if live && settings.chargingTakeover && battery.charging {
            s.applyChargingStyle()
        }
        // A quick status you picked (real island only).
        if live, let item = settings.activeStatus {
            s.accentSync = .fixed
            s.left = SlotConfig(content: .emoji, text: item.emoji)
            s.right = item.text.count <= 9
                ? SlotConfig(content: .text, text: item.text, colorHex: item.hex)
                : SlotConfig(content: .marquee, text: item.text, colorHex: item.hex)
            s.minimal = SlotConfig(content: .emoji, text: item.emoji)
            s.expandedTitle = item.text
            s.expandedSubtitle = ""
            s.keylineHex = item.hex
        }
        // Accent sync: let the accent come from time, battery, weather or album art.
        switch s.accentSync {
        case .fixed:
            break
        case .timeOfDay:
            s.keylineHex = Self.timeOfDayHex(now)
        case .battery:
            if battery.charging {
                s.keylineHex = "34C759FF"
            } else if battery.level >= 0 && battery.level <= 20 {
                s.keylineHex = "FF3B30FF"
            } else if battery.level >= 0 && battery.level <= 50 {
                s.keylineHex = "FFCC00FF"
            } else {
                s.keylineHex = "30D158FF"
            }
        case .weather:
            if let hex = Self.weatherHex(info.weatherSymbol) { s.keylineHex = hex }
        case .albumArt:
            if let hex = albumAccentHex { s.keylineHex = hex }
        }
        if live && settings.lowBatteryAlert && !battery.charging && battery.level >= 0 && battery.level <= 20 {
            s.keylineHex = "FF3B30FF"
        }
        // Slots set to follow the accent take its color.
        let slotPaths: [WritableKeyPath<IslandState, SlotConfig>] = [\.left, \.right, \.minimal]
        for path in slotPaths where s[keyPath: path].useAccent {
            s[keyPath: path].colorHex = s.keylineHex
        }

        // Per-slot rotation and "show only when" rules
        func resolved(_ slot: SlotConfig) -> SlotConfig {
            var out = slot
            if !out.rotate.isEmpty {
                var cycle: [SlotContent] = [out.content]
                for raw in out.rotate {
                    if let extra = SlotContent(rawValue: raw) { cycle.append(extra) }
                }
                let step = max(2.0, out.rotateSeconds)
                out.content = cycle[Int(now.timeIntervalSince1970 / step) % cycle.count]
            }
            if live && !out.showWhen.isEmpty && !slotCondition(out.showWhen, battery: battery, now: now) {
                out.content = .empty
            }
            return out
        }
        s.left = resolved(s.left)
        s.right = resolved(s.right)
        s.minimal = resolved(s.minimal)

        // Extra live values, only shipped when a slot or chip shows them (keeps the island's data small)
        let chipSet: Set<String> = (s.lockChips || s.expandedChips) ? Set(s.chipKinds) : Set<String>()
        func chipOn(_ kind: ChipKind) -> Bool { chipSet.contains(kind.rawValue) }
        if s.uses(.nextEvent) || chipOn(.nextEvent) {
            s.nextEventTitle = String(info.nextEventTitle.prefix(20))
            s.nextEventStart = info.nextEventStart
        }
        s.netType = (s.uses(.network) || chipOn(.network)) ? networkWatcher.type : ""
        s.lowPower = s.uses(.lowPower) ? SystemReader.lowPower : false
        if s.uses(.uv) || chipOn(.uv) { s.uv = info.uv }
        if s.uses(.rainChance) || chipOn(.rain) { s.rainChance = info.rainChance }
        if s.uses(.wind) || chipOn(.wind) { s.wind = info.wind }
        if s.uses(.airQuality) || chipOn(.aqi) { s.aqi = info.aqi }
        if s.uses(.storage) || chipOn(.storage) { s.storageGB = info.storageGB }
        if s.uses(.volume) { s.volume = SystemReader.volumePercent }
        if s.uses(.brightness) { s.brightnessPct = SystemReader.brightnessPercent }
        s.stepsGoal = settings.stepsGoal
        let reachedToday = settings.counterGoal > 0 && settings.counter >= settings.counterGoal
        s.streak = settings.streak + (reachedToday ? 1 : 0)
        if !s.graphKind.isEmpty {
            let source = s.graphKind == "steps" ? stepsHistory : batteryHistory
            s.spark = Array(source.suffix(24))
        }
        s.reactions = settings.showReactions ? Array(settings.reactionEmojis.filter { !$0.isEmpty }.prefix(5)) : []

        // Tools
        s.counter = settings.counter
        s.counterGoal = settings.counterGoal
        s.showCounterButtons = settings.counterButtons && s.uses(.counter)
        s.showTimerButton = s.uses(.pomodoro)
        s.pomoPhase = settings.pomoPhase
        s.pomoStart = settings.pomoStart
        s.pomoEnd = settings.pomoEnd
        s.daysSince = settings.daysSince
        s.worldTZ = settings.worldTZ
        s.buttonKinds = settings.expandedButtons
        if s.uses(.slideshow) && !settings.slideshowPhotos.isEmpty {
            let photos = settings.slideshowPhotos
            let index = Int(now.timeIntervalSince1970 / max(1, settings.slideSeconds)) % photos.count
            s.slideData = photos[index]
        }
        let chipsShowCrypto = (s.lockChips || s.expandedChips) && s.chipKinds.contains(ChipKind.crypto.rawValue)
        if s.uses(.crypto) || chipsShowCrypto {
            s.cryptoSymbol = settings.cryptoCoin
            s.cryptoPrice = info.cryptoPrice
            s.cryptoChange = info.cryptoChange
        }
        if s.uses(.messages) {
            let lines = settings.messagesText
                .split(whereSeparator: { $0.isNewline })
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !lines.isEmpty {
                let step = max(2.0, settings.messageSeconds)
                let index = Int(now.timeIntervalSince1970 / step) % lines.count
                s.rotatingText = String(lines[index].prefix(40))
            }
        }

        // Accessibility, bedtime and quick launch
        if settings.reduceMotion { s.frame = 0 }
        if settings.highContrast {
            s.lockStyle = .black
            s.islandBg = .off
            s.glow = false
        }
        s.textScale = settings.textScale
        s.bedtimeMinute = settings.bedtimeMinute
        s.links = settings.quickLinks.filter { !$0.url.isEmpty }.prefix(4).map { $0.emoji + "|" + $0.url }

        // Only ship heavy data that a slot actually shows
        s.musicArt = s.uses(.musicArt) ? info.musicArt : nil
        if !s.uses(.image) { s.imageData = nil }
        if budget { s.fitToBudget() }
        return s
    }

    /// The user's music layout. Each side can use their own preset's slot, and the
    /// minimal bubble always stays whatever they chose for their preset.
    private func applyMusicLayout(to s: inout IslandState) {
        if !settings.musicLeftUsesMine { s.left = settings.musicLeft }
        if !settings.musicRightUsesMine { s.right = settings.musicRight }
        if settings.musicSongTitle && !s.musicTitle.isEmpty {
            s.expandedTitle = s.musicTitle
            s.expandedSubtitle = s.musicArtist
        }
    }

    private func liveState(now: Date = Date()) -> IslandState {
        var base = config
        if var takeover = takeoverStyle {
            if takeover.imageData == nil { takeover.imageData = config.imageData }
            base = takeover
        }
        return compose(base: base, now: now, frame: frame, cycleStart: cycleStart, cycleLength: max(1, cycleLength),
                       sessionStart: activityStart, budget: true, live: true, forceMusic: false)
    }

    /// The heartbeat. Runs whenever the app process is alive (foreground, or kept alive in background).
    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                let seconds = max(0.5, self.frameInterval)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }

    private func tick() async {
        let now = Date()
        refreshInfo(now: now)
        refreshExtraInfo(now: now)
        updateMusicDetection(now: now)
        checkSchedule(now: now)
        checkHoliday(now: now)
        dailyCounterReset(now: now)
        checkPomodoro(now: now)
        checkLowBattery()
        updateHistory(now: now)
        checkStatusExpiry(now: now)
        checkBubbleExpiry(now: now)
        checkRecap(now: now)
        evaluateTakeover(now: now)
        await syncMusicHide()

        guard isRunning, !waitingForForeground, !isHiddenForMusic, let current = activity else { return }
        if current.activityState != .active || now.timeIntervalSince(activityStart) > 7.75 * 3600 {
            await replaceActivity()
            return
        }

        if !paused {
            frame &+= 1
            if now >= cycleStart.addingTimeInterval(max(1, cycleLength)) {
                cycleStart = now
            }
        }

        var alert: AlertConfiguration?
        let quiet = quietActive(now)
        let battery = batteryInfo()
        if battery.charging && !wasCharging && settings.chargingMode && !quiet {
            let text = battery.level >= 0 ? "Charging · \(battery.level)%" : "Charging"
            setBanner(text, now: now)
            alert = makeAlert(text)
        }
        wasCharging = battery.charging

        if settings.hourlyPopOut, !quiet, let chime = hourlyChimeText(now) {
            setBanner(chime, now: now)
            alert = makeAlert(chime)
        }

        if let text = pendingBanner {
            pendingBanner = nil
            if !quiet {
                setBanner(text, now: now)
                alert = makeAlert(text)
            }
        }

        if let until = bannerUntil, now > until {
            bannerText = ""
            bannerUntil = nil
        }

        // "Stay in the small bubble": update rarely and never pop out, so another app's Live Activity
        // (like Uber Eats) keeps the big spot and yours sits in the minimal bubble.
        if settings.stayInBubble {
            alert = nil
            if now.timeIntervalSince(lastPush) < max(10, settings.bubbleSeconds) { return }
        }

        // While paused, only refresh occasionally to save battery.
        if paused && alert == nil && now.timeIntervalSince(lastPush) < 15 { return }

        await current.update(ActivityContent(state: liveState(now: now), staleDate: nil), alertConfiguration: alert)
        lastPush = now
    }

    private func refreshInfo(now: Date) {
        let appActive = UIApplication.shared.applicationState == .active
        let musicSlots = config.usesAny([.music, .musicArt, .musicBars])

        if musicSlots || settings.musicMode != .keep || config.accentSync == .albumArt,
           let snap = musicWatcher.poll(canPrompt: appActive && musicSlots) {
            var updated = info
            updated.musicTitle = snap.title
            updated.musicArtist = snap.artist
            updated.musicPlaying = snap.playing
            updated.musicArt = snap.art
            if updated.musicArt != info.musicArt {
                albumAccentHex = snap.art.flatMap { UIImage(data: $0) }.flatMap { PaletteExtractor.palette(from: $0).first }
            }
            if updated != info { info = updated }
        }

        // Lock Screen chips use steps/weather only if they're already set up (no surprise permission prompts).
        let rulesNeedSteps = settings.rulesEnabled && settings.rules.contains { $0.enabled && $0.kind == .stepsGoal }
        let wantsSteps = config.uses(.steps) || config.uses(.stepsRing) || config.graphKind == "steps"
            || settings.recapEnabled || rulesNeedSteps
            || (config.lockChips && CMPedometer.authorizationStatus() == .authorized)
        if wantsSteps, !stepsInFlight,
           lastStepsFetch.map({ now.timeIntervalSince($0) > 30 }) ?? true {
            stepsInFlight = true
            lastStepsFetch = now
            Task {
                if let count = await self.stepsWatcher.todaySteps(), count != self.info.steps {
                    self.info.steps = count
                }
                self.stepsInFlight = false
            }
        }

        let weatherSlot = config.uses(.weather)
        let wantsWeather = weatherSlot || (config.lockChips && settings.latitude != nil)
        if wantsWeather, !weatherInFlight,
           lastWeatherFetch.map({ now.timeIntervalSince($0) > 900 }) ?? true {
            weatherInFlight = true
            lastWeatherFetch = now
            Task {
                if weatherSlot, self.settings.latitude == nil, appActive, !self.triedAutoLocation {
                    self.triedAutoLocation = true
                    await self.updateLocation()
                }
                if let lat = self.settings.latitude, let lon = self.settings.longitude,
                   let reading = await WeatherService.fetch(lat: lat, lon: lon, fahrenheit: self.settings.useFahrenheit) {
                    self.info.weatherTemp = reading.temp
                    self.info.weatherSymbol = reading.symbol
                    self.lastWeatherFetch = Date()
                }
                self.weatherInFlight = false
            }
        }

        let cryptoChips = (config.lockChips || config.expandedChips) && config.chipKinds.contains(ChipKind.crypto.rawValue)
        if config.uses(.crypto) || cryptoChips, !cryptoInFlight,
           lastCryptoFetch.map({ now.timeIntervalSince($0) > 60 }) ?? true {
            cryptoInFlight = true
            lastCryptoFetch = now
            let coin = settings.cryptoCoin
            Task {
                if let reading = await CryptoService.fetch(symbol: coin) {
                    self.info.cryptoPrice = reading.price
                    self.info.cryptoChange = reading.change
                }
                self.cryptoInFlight = false
            }
        }
    }

    // MARK: Music detection

    /// Music counts as playing when Apple Music reports it, or when another app's audio asks
    /// others to stay quiet (Spotify, YouTube, etc). Phone and FaceTime calls are ignored.
    private func updateMusicDetection(now: Date) {
        let callActive = callObserver.calls.contains { !$0.hasEnded }
        let otherAudio = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
        let playing = !callActive && (info.musicPlaying || otherAudio)

        // Debounce so skipping songs doesn't make the island flicker.
        if playing {
            musicGoneSince = nil
            let since = musicSeenSince ?? now
            musicSeenSince = since
            if !musicActive && now.timeIntervalSince(since) >= 2 {
                musicActive = true
                if settings.musicMode == .showMusic { configChanged() }
            }
        } else {
            musicSeenSince = nil
            let since = musicGoneSince ?? now
            musicGoneSince = since
            if musicActive && now.timeIntervalSince(since) >= 4 {
                musicActive = false
                if settings.musicMode == .showMusic { configChanged() }
            }
        }
    }

    /// "Let music take over": end the island while music plays, bring it back after.
    private func syncMusicHide() async {
        guard isRunning else { return }
        let shouldHide = musicActive && settings.musicMode == .hide
        if shouldHide && !isHiddenForMusic {
            isHiddenForMusic = true
            await endAllActivities()
            status = "Hidden while music plays"
        } else if !shouldHide && isHiddenForMusic {
            isHiddenForMusic = false
            await restartActivity()
        }
    }

    // MARK: Rules and shuffle

    private var headphonesConnected: Bool {
        let kinds: [AVAudioSession.Port] = [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains { kinds.contains($0.portType) }
    }

    /// The first enabled rule that matches right now.
    private func matchingRule(now: Date) -> IslandRule? {
        guard settings.rulesEnabled else { return nil }
        let battery = batteryInfo()
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let minute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let symbol = info.weatherSymbol
        for rule in settings.rules where rule.enabled {
            let matches: Bool
            switch rule.kind {
            case .batteryBelow:
                matches = battery.level >= 0 && !battery.charging && battery.level <= rule.number
            case .charging:
                matches = battery.charging
            case .music:
                matches = musicActive
            case .headphones:
                matches = headphonesConnected
            case .rain:
                matches = symbol.contains("rain") || symbol.contains("drizzle") || symbol.contains("bolt")
            case .snow:
                matches = symbol.contains("snow")
            case .hot:
                matches = (info.weatherTemp ?? Int.min) >= rule.number
            case .cold:
                matches = (info.weatherTemp ?? Int.max) <= rule.number
            case .timeRange:
                if rule.startMinute <= rule.endMinute {
                    matches = minute >= rule.startMinute && minute < rule.endMinute
                } else {
                    matches = minute >= rule.startMinute || minute < rule.endMinute
                }
            case .weekend:
                matches = cal.isDateInWeekend(now)
            case .inMeeting:
                matches = info.nextEventInProgress && !info.nextEventTitle.isEmpty
            case .lowPowerMode:
                matches = SystemReader.lowPower
            case .stepsGoal:
                matches = info.steps >= 0 && info.steps >= settings.stepsGoal
            case .cellular:
                matches = networkWatcher.type == "cell"
            case .focusActive:
                matches = !settings.pomoPhase.isEmpty
            }
            if matches { return rule }
        }
        return nil
    }

    private func pickShuffle(now: Date) {
        let pool: [SavedPreset]
        switch settings.shuffleSource {
        case "favorites": pool = allPresets.filter { settings.favoriteIDs.contains($0.id) }
        case "mine": pool = savedPresets
        default: pool = allPresets
        }
        let choices = pool.filter { $0.name != shuffleName }
        if let pick = (choices.isEmpty ? pool : choices).randomElement() {
            shuffleStyle = pick.style
            shuffleName = pick.name
        }
        lastShuffle = now
    }

    /// Rules beat shuffle; both swap the look without touching your saved style.
    private func evaluateTakeover(now: Date) {
        var style: IslandState?
        var label = ""
        if let rule = matchingRule(now: now), let preset = findPreset(rule.presetID) {
            style = preset.style
            label = "\(rule.kind.label) → \(preset.name)"
        } else if quietActive(now), !settings.quietPresetID.isEmpty, let preset = findPreset(settings.quietPresetID) {
            style = preset.style
            label = "Quiet hours → \(preset.name)"
        } else if settings.shuffleEnabled {
            let due = lastShuffle.map { now.timeIntervalSince($0) >= Double(max(1, settings.shuffleMinutes)) * 60 } ?? true
            if due || shuffleStyle == nil { pickShuffle(now: now) }
            style = shuffleStyle
            label = shuffleName.isEmpty ? "" : "Shuffle → \(shuffleName)"
        } else {
            shuffleStyle = nil
            shuffleName = ""
        }
        let changed = style != takeoverStyle
        takeoverStyle = style
        if takeoverLabel != label { takeoverLabel = label }
        if changed { configChanged() }
    }

    /// A smooth accent that drifts through the day: night indigo, sunrise orange, sky blue, sunset pink.
    private static func timeOfDayHex(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let t = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
        let anchors: [(Double, Double, Double, Double)] = [
            (0, 0.18, 0.16, 0.55), (5, 0.29, 0.25, 0.82), (7, 1.0, 0.62, 0.26), (10, 0.31, 0.76, 0.97),
            (16, 0.31, 0.76, 0.97), (18.5, 1.0, 0.37, 0.54), (20.5, 0.56, 0.36, 1.0), (24, 0.18, 0.16, 0.55)
        ]
        for i in 0..<(anchors.count - 1) {
            let a = anchors[i]
            let b = anchors[i + 1]
            if t >= a.0 && t <= b.0 {
                let f = (t - a.0) / max(0.001, b.0 - a.0)
                let r = a.1 + (b.1 - a.1) * f
                let g = a.2 + (b.2 - a.2) * f
                let bl = a.3 + (b.3 - a.3) * f
                return String(format: "%02X%02X%02XFF", Int(r * 255), Int(g * 255), Int(bl * 255))
            }
        }
        return "8E5CFFFF"
    }

    /// Accent for the current weather: sunny yellow, rainy blue, stormy purple and so on.
    private static func weatherHex(_ symbol: String) -> String? {
        if symbol.isEmpty { return nil }
        if symbol.contains("bolt") { return "A259FFFF" }
        if symbol.contains("snow") { return "DFF4FFFF" }
        if symbol.contains("rain") || symbol.contains("drizzle") { return "4FA3FFFF" }
        if symbol.contains("fog") { return "B0BEC5FF" }
        if symbol.contains("moon") { return "8E5CFFFF" }
        if symbol.contains("sun") { return "FFCC00FF" }
        return "9AA5B1FF"
    }

    // MARK: Smart pop-outs

    private func queueBanner(_ text: String) {
        guard isRunning, !isHiddenForMusic else { return }
        pendingBanner = text
    }

    private func checkLowBattery() {
        guard settings.lowBatteryAlert else { return }
        let battery = batteryInfo()
        guard battery.level >= 0 else { return }
        if battery.charging || battery.level > 20 {
            lowNotified = 100
            return
        }
        if battery.level <= 10 && lowNotified > 10 {
            lowNotified = 10
            queueBanner("Battery \(battery.level)%")
        } else if battery.level <= 20 && lowNotified > 20 {
            lowNotified = 20
            queueBanner("Low battery · \(battery.level)%")
        }
    }

    private func routeChanged(reasonRaw: UInt?) {
        guard settings.headphonesPopOut, isRunning, !isHiddenForMusic,
              let raw = reasonRaw,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .newDeviceAvailable else { return }
        let kinds: [AVAudioSession.Port] = [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
        if let output = AVAudioSession.sharedInstance().currentRoute.outputs.first(where: { kinds.contains($0.portType) }) {
            queueBanner("🎧 \(output.portName)")
        }
    }

    private func checkPomodoro(now: Date) {
        guard !settings.pomoPhase.isEmpty, now >= settings.pomoEnd else { return }
        if settings.pomoPhase == "focus" {
            settings.focusRoundsToday += 1
            startPhase("break", minutes: settings.breakMinutes, now: now)
            queueBanner("Break time ☕")
        } else {
            startPhase("focus", minutes: settings.focusMinutes, now: now)
            queueBanner("Focus time 🍅")
        }
    }

    private func dailyCounterReset(now: Date) {
        guard settings.counterResetsDaily else { return }
        let day = Self.dayFormatter.string(from: now)
        guard settings.counterDay != day else { return }
        var s = settings
        if !s.counterDay.isEmpty {
            if s.counterGoal > 0 { s.streak = s.counter >= s.counterGoal ? s.streak + 1 : 0 }
            s.counter = 0
            s.focusRoundsToday = 0
        }
        s.counterDay = day
        settings = s
    }

    // MARK: Schedule, holidays, hourly

    /// The holiday or birthday preset for today, if the matching switch is on.
    private func holidayPresetID(for now: Date) -> String? {
        let cal = Calendar.current
        let c = cal.dateComponents([.month, .day], from: now)
        guard let month = c.month, let day = c.day else { return nil }
        if settings.birthdayEnabled {
            let b = cal.dateComponents([.month, .day], from: settings.birthday)
            if b.month == month && b.day == day { return "birthday" }
        }
        if settings.holidayAuto {
            switch (month, day) {
            case (10, 24...31): return "halloween"
            case (12, 20...26): return "christmas"
            case (12, 31), (1, 1...2): return "newyear"
            case (2, 10...14): return "valentine"
            default: break
            }
        }
        return nil
    }

    private func checkHoliday(now: Date) {
        guard let id = holidayPresetID(for: now) else {
            // Holiday's over: if its preset is still showing, go back to the default.
            if !lastHolidayPresetID.isEmpty {
                if settings.currentPresetID == lastHolidayPresetID { applyDefault() }
                lastHolidayPresetID = ""
                UserDefaults.standard.set("", forKey: Keys.holidayPresetKey)
            }
            return
        }
        let c = Calendar.current.dateComponents([.month, .day], from: now)
        let key = "\(id)@\(c.month ?? 0)-\(c.day ?? 0)"
        guard key != lastHolidayKey else { return }
        lastHolidayKey = key
        UserDefaults.standard.set(key, forKey: Keys.holidayKey)
        lastHolidayPresetID = id
        UserDefaults.standard.set(id, forKey: Keys.holidayPresetKey)
        applyPreset(id: id)
    }

    private func checkSchedule(now: Date) {
        let schedule = settings.schedule
        guard schedule.enabled, !schedule.blocks.isEmpty else { return }
        // A holiday or birthday preset wins for the day.
        if holidayPresetID(for: now) != nil { return }
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let nowMinute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let sorted = schedule.blocks.sorted { $0.startMinute < $1.startMinute }
        let startOfDay = cal.startOfDay(for: now)

        let block: ScheduleBlock
        let blockStart: Date
        if let current = sorted.last(where: { $0.startMinute <= nowMinute }) {
            block = current
            blockStart = startOfDay.addingTimeInterval(TimeInterval(current.startMinute * 60))
        } else {
            // Before the first block today: still in yesterday's last block.
            block = sorted[sorted.count - 1]
            blockStart = startOfDay.addingTimeInterval(TimeInterval(block.startMinute * 60 - 86_400))
        }

        let key = "\(block.id)@\(Int(blockStart.timeIntervalSince1970))"
        guard key != lastScheduleKey else { return }
        lastScheduleKey = key
        UserDefaults.standard.set(key, forKey: Keys.scheduleKey)
        applyPreset(id: block.presetID)
    }

    private func hourlyChimeText(_ now: Date) -> String? {
        let minute = Calendar.current.component(.minute, from: now)
        let hourKey = Int(now.timeIntervalSince1970 / 3600)
        guard minute == 0, hourKey != lastChimeHour else { return nil }
        lastChimeHour = hourKey
        return now.formatted(date: .omitted, time: .shortened)
    }

    private func setBanner(_ text: String, now: Date) {
        bannerText = text
        bannerUntil = now.addingTimeInterval(8)
    }

    private func makeAlert(_ title: String) -> AlertConfiguration {
        let sound: AlertConfiguration.AlertSound
        if !settings.chimeSound {
            sound = .named("silence.wav")
        } else if settings.chimeName == "default" {
            sound = .default
        } else {
            sound = .named("chime-" + settings.chimeName + ".wav")
        }
        return AlertConfiguration(title: LocalizedStringResource(stringLiteral: title),
                                  body: LocalizedStringResource(stringLiteral: ""),
                                  sound: sound)
    }

    // MARK: Activity plumbing

    private func configChanged() {
        guard isRunning else { return }
        Task { await self.pushUpdate() }
    }

    private func pushUpdate() async {
        guard let current = activity, current.activityState == .active else { return }
        await current.update(ActivityContent(state: liveState(), staleDate: nil))
        lastPush = Date()
    }

    /// Starts a fresh activity when none is running (after music, or after iOS ended it).
    private func restartActivity() async {
        activityStart = Date()
        cycleStart = activityStart
        frame = 0
        do {
            activity = try Activity.request(
                attributes: IslandAttributes(name: "Island"),
                content: ActivityContent(state: liveState(), staleDate: nil),
                pushType: nil)
            lastPush = Date()
            status = "Island is back"
        } catch {
            // iOS may refuse to start an activity while the app is in the background.
            waitingForForeground = true
            status = "Open the app to bring your island back"
            notifyRestartNeeded()
        }
    }

    /// Swaps in a new activity before iOS's 8-hour limit (start new, then end old, so there's no gap).
    private func replaceActivity() async {
        let old = activity
        activityStart = Date()
        cycleStart = activityStart
        frame = 0
        do {
            activity = try Activity.request(
                attributes: IslandAttributes(name: "Island"),
                content: ActivityContent(state: liveState(), staleDate: nil),
                pushType: nil)
            await old?.end(nil, dismissalPolicy: .immediate)
        } catch {
            waitingForForeground = true
            status = "iOS paused the island. Opening the app restarts it."
            notifyRestartNeeded()
        }
    }

    private func notifyRestartNeeded() {
        let content = UNMutableNotificationContent()
        content.title = "Dynamic Island paused"
        content.body = "Tap to bring your island back."
        let request = UNNotificationRequest(identifier: "island.restart", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func endAllActivities() async {
        for a in Activity<IslandAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Keys.config)
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Keys.settings)
        }
    }
}

// MARK: - Presets: order and locking

extension IslandManager {
    /// Puts a brand new preset at the front (or the back, if you prefer).
    func placeNewPreset(_ id: String) {
        var ids = allPresets.map { $0.id }
        ids.removeAll { $0 == id }
        if settings.newPresetsFirst {
            ids.insert(id, at: 0)
        } else {
            ids.append(id)
        }
        settings.presetOrder = ids
    }

    func movePresets(from source: IndexSet, to destination: Int) {
        var ids = allPresets.map { $0.id }
        ids.move(fromOffsets: source, toOffset: destination)
        settings.presetOrder = ids
        Haptics.tap()
    }

    func moveToFront(_ id: String) {
        var ids = allPresets.map { $0.id }
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
        settings.presetOrder = ids
        Haptics.tap()
        status = "Moved to the front"
    }

    func resetPresetOrder() {
        settings.presetOrder = []
        status = "Order reset"
    }

    func isLocked(_ id: String) -> Bool { settings.lockedIDs.contains(id) }

    func toggleLock(_ id: String) {
        if let index = settings.lockedIDs.firstIndex(of: id) {
            settings.lockedIDs.remove(at: index)
            status = "Unlocked"
        } else {
            settings.lockedIDs.append(id)
            status = "Locked. It can't be changed by accident."
        }
        Haptics.tap()
    }
}

// MARK: - Undo, redo, compare

extension IslandManager {
    /// Slider drags make dozens of tiny changes, so only the state from before each burst is kept.
    func recordUndo(previous: IslandState) {
        guard !applyingHistory, previous != config else { return }
        let now = Date()
        if now.timeIntervalSince(lastUndoPush) > 0.8 {
            undoStack.append(previous)
            if undoStack.count > 60 { undoStack.removeFirst() }
        }
        lastUndoPush = now
        redoStack.removeAll()
        updateUndoFlags()
    }

    func updateUndoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        applyingHistory = true
        redoStack.append(config)
        config = previous
        applyingHistory = false
        updateUndoFlags()
        status = "Undid your last change"
        Haptics.tap()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        applyingHistory = true
        undoStack.append(config)
        config = next
        applyingHistory = false
        updateUndoFlags()
        status = "Redid that change"
        Haptics.tap()
    }
}

// MARK: - Status, pop-outs, quiet hours, recap, history

extension IslandManager {
    func setStatus(_ item: StatusItem?) {
        var s = settings
        s.activeStatus = item
        if item != nil && s.statusHours > 0 {
            s.statusExpires = Date().addingTimeInterval(Double(s.statusHours) * 3600)
        } else {
            s.statusExpires = nil
        }
        settings = s
        Haptics.tap()
        status = item == nil ? "Status cleared" : "Status set: \(item?.text ?? "")"
    }

    /// Used by the Shortcuts action: put any text on the island.
    func setStatusText(emoji: String, text: String) {
        let cleanEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = StatusItem(id: "shortcut", emoji: cleanEmoji.isEmpty ? "💬" : cleanEmoji,
                              text: String(text.prefix(30)), hex: config.keylineHex)
        setStatus(item)
    }

    func checkStatusExpiry(now: Date) {
        if let end = settings.statusExpires, now >= end { setStatus(nil) }
    }

    /// Pops text out of the island right away (used for emoji reactions).
    func popOutNow(_ text: String) async {
        guard isRunning, !isHiddenForMusic, let current = activity, current.activityState == .active else { return }
        let now = Date()
        setBanner(text, now: now)
        await current.update(ActivityContent(state: liveState(now: now), staleDate: nil),
                             alertConfiguration: makeAlert(text))
        lastPush = now
    }

    /// True during your quiet hours: no pop-outs, alerts or sounds.
    func quietActive(_ now: Date) -> Bool {
        guard settings.quietEnabled else { return false }
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let start = settings.quietStartMinute
        let end = settings.quietEndMinute
        return start <= end ? (minute >= start && minute < end) : (minute >= start || minute < end)
    }

    private func recapText() -> String {
        var parts: [String] = []
        if info.steps >= 0 { parts.append("\(info.steps.formatted()) steps") }
        if settings.counterGoal > 0 { parts.append("\(settings.counter)/\(settings.counterGoal) goal") }
        if settings.focusRoundsToday > 0 { parts.append("\(settings.focusRoundsToday) 🍅") }
        if settings.streak > 0 { parts.append("🔥\(settings.streak)") }
        return parts.isEmpty ? "Good evening 🌙" : "Today · " + parts.joined(separator: " · ")
    }

    func checkRecap(now: Date) {
        guard settings.recapEnabled else { return }
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let day = Self.dayStamp(now)
        guard minute >= settings.recapMinute, minute < settings.recapMinute + 30, settings.lastRecapDay != day else { return }
        settings.lastRecapDay = day
        queueBanner(recapText())
    }

    /// Saves a battery and steps reading every half hour for the mini graphs.
    func updateHistory(now: Date) {
        let interval: TimeInterval = (batteryHistory.count < 3) ? 120 : 1800
        if let last = lastHistorySample, now.timeIntervalSince(last) < interval { return }
        lastHistorySample = now
        let day = Self.dayStamp(now)
        if day != historyDay {
            historyDay = day
            stepsHistory = []
            UserDefaults.standard.set(day, forKey: "historyDay")
        }
        let battery = batteryInfo()
        if battery.level >= 0 { batteryHistory.append(battery.level) }
        if info.steps >= 0 { stepsHistory.append(info.steps) }
        batteryHistory = Array(batteryHistory.suffix(24))
        stepsHistory = Array(stepsHistory.suffix(24))
        UserDefaults.standard.set(batteryHistory, forKey: "batteryHistory")
        UserDefaults.standard.set(stepsHistory, forKey: "stepsHistory")
    }

    private static func dayStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Calendar, extra weather, air quality and storage.
    func refreshExtraInfo(now: Date) {
        let appActive = UIApplication.shared.applicationState == .active
        let chipSet: Set<String> = (config.lockChips || config.expandedChips) ? Set(config.chipKinds) : Set<String>()
        func chipOn(_ kind: ChipKind) -> Bool { chipSet.contains(kind.rawValue) }

        let rulesNeedCalendar = settings.rulesEnabled && settings.rules.contains { $0.enabled && $0.kind == .inMeeting }
        if config.uses(.nextEvent) || chipOn(.nextEvent) || rulesNeedCalendar,
           lastCalendarFetch.map({ now.timeIntervalSince($0) > 60 }) ?? true {
            lastCalendarFetch = now
            if calendarWatcher.needsPrompt {
                if appActive {
                    Task { _ = await self.calendarWatcher.requestAccess() }
                }
            } else if let next = calendarWatcher.upcoming(now: now) {
                info.nextEventTitle = next.title
                info.nextEventStart = next.start
                info.nextEventInProgress = next.inProgress
            } else if !info.nextEventTitle.isEmpty {
                info.nextEventTitle = ""
                info.nextEventInProgress = false
            }
        }

        let wantsExtras = config.uses(.uv) || config.uses(.rainChance) || config.uses(.wind)
            || chipOn(.uv) || chipOn(.rain) || chipOn(.wind)
        if wantsExtras, !extrasInFlight, let lat = settings.latitude, let lon = settings.longitude,
           lastExtrasFetch.map({ now.timeIntervalSince($0) > 900 }) ?? true {
            extrasInFlight = true
            lastExtrasFetch = now
            let fahrenheit = settings.useFahrenheit
            Task {
                if let extras = await WeatherService.fetchExtras(lat: lat, lon: lon, fahrenheit: fahrenheit) {
                    self.info.uv = extras.uv
                    self.info.rainChance = extras.rainChance
                    self.info.wind = extras.wind
                }
                self.extrasInFlight = false
            }
        }

        if config.uses(.airQuality) || chipOn(.aqi), !aqiInFlight,
           let lat = settings.latitude, let lon = settings.longitude,
           lastAQIFetch.map({ now.timeIntervalSince($0) > 1800 }) ?? true {
            aqiInFlight = true
            lastAQIFetch = now
            Task {
                if let value = await AirQualityService.fetch(lat: lat, lon: lon) {
                    self.info.aqi = value
                }
                self.aqiInFlight = false
            }
        }

        if config.uses(.storage) || chipOn(.storage),
           lastStorageFetch.map({ now.timeIntervalSince($0) > 60 }) ?? true {
            lastStorageFetch = now
            info.storageGB = SystemReader.freeStorageGB() ?? -1
        }
    }

    /// For the health check screen.
    var batteryIsExact: Bool { BatteryReader.isExact }
    var batteryLevelNow: Int { BatteryReader.read().level }
}

// MARK: - Saving your setup so re-signing the app doesn't lose it

extension IslandManager {
    /// Everything that makes up your setup, as one file's worth of data.
    func backupData(includeLocation: Bool) -> Data? {
        var exported = settings
        if !includeLocation {
            exported.latitude = nil
            exported.longitude = nil
        }
        let backup = BackupData(config: config.styleOnly(), settings: exported, presets: savedPresets,
                                  speed: frameInterval, loop: cycleLength, keepAlive: keepAlive)
        return try? JSONEncoder().encode(backup)
    }

    /// Waits a few seconds after the last change, then copies your setup to the Keychain.
    func scheduleAutoSave() {
        guard settings.autoSave else { return }
        autoSaveTask?.cancel()
        autoSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.writeKeychainBackup()
        }
    }

    func writeKeychainBackup() {
        guard settings.autoSave, let data = backupData(includeLocation: true) else { return }
        let saved = KeychainBackup.save(data)
        autoSaveOK = saved
        if saved { lastAutoSave = Date() }
    }

    /// Called when the app goes to the background, so the very last change is never lost.
    func saveBackupNow() {
        autoSaveTask?.cancel()
        writeKeychainBackup()
    }

    /// Restores from a saved file or a pasted code.
    @discardableResult
    func restoreBackup(data: Data) -> Bool {
        var payload = data
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           text.hasPrefix("ISB1:"), let decoded = Data(base64Encoded: String(text.dropFirst(5))) {
            payload = decoded
        }
        guard let backup = try? JSONDecoder().decode(BackupData.self, from: payload) else {
            status = "That isn't an Island Studio backup"
            return false
        }
        var restored = backup.settings
        if restored.latitude == nil {
            restored.latitude = settings.latitude
            restored.longitude = settings.longitude
        }
        config = backup.config
        settings = restored
        savedPresets = backup.presets
        if let value = backup.speed { frameInterval = value }
        if let value = backup.loop { cycleLength = value }
        if let value = backup.keepAlive { keepAlive = value }
        status = "Backup restored"
        Haptics.success()
        return true
    }
}

// MARK: - Small bubble mode

extension IslandManager {
    /// Turns "stay in the small bubble" on or off. `hours` of 0 means until you turn it off;
    /// leave it nil to use the hours you picked in the app.
    func setBubbleMode(_ on: Bool, hours: Int? = nil) {
        var s = settings
        let chosen = hours ?? s.bubbleHours
        s.stayInBubble = on
        s.bubbleUntil = (on && chosen > 0) ? Date().addingTimeInterval(Double(chosen) * 3600) : nil
        settings = s
        Haptics.tap()
        if on {
            status = chosen > 0 ? "Small bubble mode on for \(chosen) hour\(chosen == 1 ? "" : "s")" : "Small bubble mode on"
        } else {
            status = "Small bubble mode off"
        }
    }

    func checkBubbleExpiry(now: Date) {
        if let end = settings.bubbleUntil, now >= end { setBubbleMode(false) }
    }
}

// MARK: - Slot conditions, live data refresh

extension IslandManager {
    /// Whether a "show only when" condition is true right now.
    func slotCondition(_ key: String, battery: (level: Int, charging: Bool), now: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        switch key {
        case "charging": return battery.charging
        case "notCharging": return !battery.charging
        case "lowBattery": return battery.level >= 0 && battery.level <= 20
        case "night": return hour >= 21 || hour < 6
        case "day": return hour >= 6 && hour < 21
        case "music": return musicActive || info.musicPlaying
        case "weekend": return Calendar.current.isDateInWeekend(now)
        case "wifi": return networkWatcher.type == "wifi"
        case "cellular": return networkWatcher.type == "cell"
        case "focus": return !settings.pomoPhase.isEmpty
        default: return true
        }
    }

    /// Forgets when each live source last refreshed, so the next tick fetches everything again.
    func refreshAllNow() {
        lastWeatherFetch = nil
        lastExtrasFetch = nil
        lastAQIFetch = nil
        lastStorageFetch = nil
        lastCalendarFetch = nil
        lastCryptoFetch = nil
        lastStepsFetch = nil
        status = "Refreshing live data…"
    }

    var networkTypeNow: String { networkWatcher.type }
}
