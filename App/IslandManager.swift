import ActivityKit
import AVFoundation
import CallKit
import CoreMotion
import SwiftUI
import UIKit
import UserNotifications

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
    private var lastPush = Date.distantPast
    private var lastScheduleKey = ""
    private var lastStepsFetch: Date?
    private var lastWeatherFetch: Date?
    private var stepsInFlight = false
    private var weatherInFlight = false
    private var triedAutoLocation = false
    private var musicSeenSince: Date?
    private var musicGoneSince: Date?

    private let musicWatcher = MusicWatcher()
    private let stepsWatcher = StepsWatcher()
    private let locationFetcher = LocationFetcher()
    private let callObserver = CXCallObserver()

    private enum Keys {
        static let config = "islandConfig"
        static let settings = "appSettings"
        static let keepAlive = "keepAlive"
        static let frameInterval = "frameInterval"
        static let cycleLength = "cycleLength"
        static let wantsRunning = "wantsRunning"
        static let scheduleKey = "lastScheduleKey"
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
        UIDevice.current.isBatteryMonitoringEnabled = true
        wasCharging = batteryInfo().charging
        reattach()
        startLoop()
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

    // MARK: - Commands from island buttons and Shortcuts

    func handle(_ command: IslandCommand) async {
        switch command {
        case .next: stepPreset(by: 1)
        case .previous: stepPreset(by: -1)
        case .togglePause: paused.toggle()
        }
        await pushUpdate()
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

    /// What the island looks like right now, animated, for the in-app preview.
    func previewState(at date: Date) -> IslandState {
        let step = max(0.5, frameInterval)
        let length = max(1, cycleLength)
        let start = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / length) * length)
        let previewFrame = paused ? frame : Int(date.timeIntervalSince1970 / step)
        return compose(base: config, now: date, frame: previewFrame, cycleStart: start, cycleLength: length,
                       sessionStart: isRunning ? activityStart : date, budget: false, overrides: true)
    }

    /// A still snapshot of any style, for preset tiles.
    func previewState(style: IslandState, at date: Date) -> IslandState {
        compose(base: style, now: date, frame: 0, cycleStart: date.addingTimeInterval(-1), cycleLength: 3,
                sessionStart: date, budget: false, overrides: false)
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
                         sessionStart: Date, budget: Bool, overrides: Bool) -> IslandState {
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
        s.musicPlaying = info.musicPlaying || musicActive
        s.steps = info.steps
        s.weatherTemp = info.weatherTemp
        s.weatherSymbol = info.weatherSymbol

        // Temporary takeovers
        if overrides {
            if settings.musicMode == .showMusic && musicActive {
                s.applyMusicStyle()
            } else if settings.chargingMode && battery.charging {
                s.applyChargingStyle()
            }
        }

        // Only ship heavy data that a slot actually shows
        s.musicArt = s.uses(.musicArt) ? info.musicArt : nil
        if !s.uses(.image) { s.imageData = nil }
        if budget { s.fitToBudget() }
        return s
    }

    private func liveState(now: Date = Date()) -> IslandState {
        compose(base: config, now: now, frame: frame, cycleStart: cycleStart, cycleLength: max(1, cycleLength),
                sessionStart: activityStart, budget: true, overrides: true)
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

    // MARK: Schedule, pop-outs

    private func checkSchedule(now: Date) {
        let schedule = settings.schedule
        guard schedule.enabled, !schedule.blocks.isEmpty else { return }
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
