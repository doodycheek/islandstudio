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
}

@MainActor
final class IslandManager: ObservableObject {
    static let shared = IslandManager()

    // MARK: - Published state

    @Published var config: IslandState {
        didSet {
            saveConfig()
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
            if oldValue.cryptoCoin != settings.cryptoCoin {
                lastCryptoFetch = nil
                info.cryptoPrice = nil
                info.cryptoChange = nil
            }
            saveSettings()
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
        didSet { PresetStore.saveCustom(savedPresets) }
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
    }

    private init() {
        let d = UserDefaults.standard
        config = Self.load(IslandState.self, key: Keys.config) ?? IslandState()
        settings = Self.load(AppSettings.self, key: Keys.settings) ?? AppSettings()
        savedPresets = PresetStore.loadCustom()
        keepAlive = d.object(forKey: Keys.keepAlive) as? Bool ?? true
        let fi = d.double(forKey: Keys.frameInterval)
        frameInterval = fi > 0 ? fi : 1.0
        let cl = d.double(forKey: Keys.cycleLength)
        cycleLength = cl > 0 ? cl : 3.0
        lastScheduleKey = d.string(forKey: Keys.scheduleKey) ?? ""
        lastHolidayKey = d.string(forKey: Keys.holidayKey) ?? ""
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
        applyKeepAlive()
        status = "Island stopped"
    }

    func appBecameActive() {
        guard UserDefaults.standard.bool(forKey: Keys.wantsRunning), !isHiddenForMusic else { return }
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
    }

    func applyPreset(id: String) {
        if let preset = PresetStore.find(id) { apply(preset) }
    }

    func stepPreset(by delta: Int) {
        let all = PresetStore.builtIns + savedPresets
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
        settings.currentPresetID = preset.id
        status = "Saved \(preset.name)"
    }

    func renamePreset(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = savedPresets.firstIndex(where: { $0.id == id }) else { return }
        savedPresets[i].name = trimmed
    }

    func deletePreset(id: String) {
        savedPresets.removeAll { $0.id == id }
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
        status = "Added \(preset.name)"
    }

    // MARK: - Backup

    func copyBackup() {
        var exported = settings
        exported.latitude = nil
        exported.longitude = nil
        let backup = BackupData(config: config.styleOnly(), settings: exported, presets: savedPresets)
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
        return compose(base: config, now: date, frame: previewFrame, cycleStart: start, cycleLength: length,
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

    private func batteryInfo() -> (level: Int, charging: Bool) {
        let level = UIDevice.current.batteryLevel
        let st = UIDevice.current.batteryState
        return (level < 0 ? -1 : Int((level * 100).rounded()), st == .charging || st == .full)
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
        if live && settings.lowBatteryAlert && !battery.charging && battery.level >= 0 && battery.level <= 20 {
            s.keylineHex = "FF3B30FF"
        }

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
        if s.uses(.crypto) {
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
        compose(base: config, now: now, frame: frame, cycleStart: cycleStart, cycleLength: max(1, cycleLength),
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
        updateMusicDetection(now: now)
        checkSchedule(now: now)
        checkHoliday(now: now)
        dailyCounterReset(now: now)
        checkPomodoro(now: now)
        checkLowBattery()
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
        let battery = batteryInfo()
        if battery.charging && !wasCharging && settings.chargingMode {
            let text = battery.level >= 0 ? "Charging · \(battery.level)%" : "Charging"
            setBanner(text, now: now)
            alert = makeAlert(text)
        }
        wasCharging = battery.charging

        if settings.hourlyPopOut, let chime = hourlyChimeText(now) {
            setBanner(chime, now: now)
            alert = makeAlert(chime)
        }

        if let text = pendingBanner {
            pendingBanner = nil
            setBanner(text, now: now)
            alert = makeAlert(text)
        }

        if let until = bannerUntil, now > until {
            bannerText = ""
            bannerUntil = nil
        }

        // While paused, only refresh occasionally to save battery.
        if paused && alert == nil && now.timeIntervalSince(lastPush) < 15 { return }

        await current.update(ActivityContent(state: liveState(now: now), staleDate: nil), alertConfiguration: alert)
        lastPush = now
    }

    private func refreshInfo(now: Date) {
        let appActive = UIApplication.shared.applicationState == .active
        let musicSlots = config.usesAny([.music, .musicArt, .musicBars])

        if musicSlots || settings.musicMode != .keep,
           let snap = musicWatcher.poll(canPrompt: appActive && musicSlots) {
            var updated = info
            updated.musicTitle = snap.title
            updated.musicArtist = snap.artist
            updated.musicPlaying = snap.playing
            updated.musicArt = snap.art
            if updated != info { info = updated }
        }

        // Lock Screen chips use steps/weather only if they're already set up (no surprise permission prompts).
        let wantsSteps = config.uses(.steps)
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

        if config.uses(.crypto), !cryptoInFlight,
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
        if !s.counterDay.isEmpty { s.counter = 0 }
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
        guard let id = holidayPresetID(for: now) else { return }
        let c = Calendar.current.dateComponents([.month, .day], from: now)
        let key = "\(id)@\(c.month ?? 0)-\(c.day ?? 0)"
        guard key != lastHolidayKey else { return }
        lastHolidayKey = key
        UserDefaults.standard.set(key, forKey: Keys.holidayKey)
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
        let sound: AlertConfiguration.AlertSound = settings.chimeSound ? .default : .named("silence.wav")
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
