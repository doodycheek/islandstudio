import AppIntents

// MARK: - Preset picker for Shortcuts

struct PresetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Island Preset"
    static var defaultQuery = PresetQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct PresetQuery: EntityQuery {
    init() {}

    func entities(for identifiers: [String]) async throws -> [PresetEntity] {
        PresetStore.all()
            .filter { identifiers.contains($0.id) }
            .map { PresetEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [PresetEntity] {
        PresetStore.all().map { PresetEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - Actions

struct SetIslandPresetIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Island Preset"
    static var description: IntentDescription = IntentDescription("Switches your Dynamic Island to one of your presets.")

    @Parameter(title: "Preset")
    var preset: PresetEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Set island to \(\.$preset)")
    }

    func perform() async throws -> some IntentResult {
        await IslandManager.shared.applyPreset(id: preset.id)
        return .result()
    }
}

struct StartIslandIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Island"
    static var description: IntentDescription = IntentDescription("Starts your custom Dynamic Island.")

    init() {}

    func perform() async throws -> some IntentResult {
        await IslandManager.shared.start()
        return .result()
    }
}

struct StopIslandIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Island"
    static var description: IntentDescription = IntentDescription("Stops your custom Dynamic Island.")

    init() {}

    func perform() async throws -> some IntentResult {
        await IslandManager.shared.stop()
        return .result()
    }
}

// MARK: - Siri / Spotlight phrases

struct IslandShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartIslandIntent(),
                    phrases: ["Start my island in \(.applicationName)"],
                    shortTitle: "Start Island",
                    systemImageName: "play.fill")
        AppShortcut(intent: NextPresetIntent(),
                    phrases: ["Next island style in \(.applicationName)"],
                    shortTitle: "Next Preset",
                    systemImageName: "forward.fill")
        AppShortcut(intent: StopIslandIntent(),
                    phrases: ["Stop my island in \(.applicationName)"],
                    shortTitle: "Stop Island",
                    systemImageName: "stop.fill")
        AppShortcut(intent: PomodoroToggleIntent(),
                    phrases: ["Start my focus timer in \(.applicationName)"],
                    shortTitle: "Focus Timer",
                    systemImageName: "timer")
        AppShortcut(intent: CounterPlusIntent(),
                    phrases: ["Add one to my counter in \(.applicationName)"],
                    shortTitle: "Add One",
                    systemImageName: "plus.circle.fill")
        AppShortcut(intent: SurpriseIntent(),
                    phrases: ["Surprise me in \(.applicationName)"],
                    shortTitle: "Surprise Preset",
                    systemImageName: "shuffle")
    }
}

// MARK: - Put your own text on the island

struct SetIslandTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Island Text"
    static var description: IntentDescription = IntentDescription("Puts your own text on the island, with an emoji.")

    @Parameter(title: "Text")
    var text: String

    @Parameter(title: "Emoji", default: "💬")
    var emoji: String

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$emoji) \(\.$text) on the island")
    }

    func perform() async throws -> some IntentResult {
        await IslandManager.shared.setStatusText(emoji: emoji, text: text)
        return .result()
    }
}

struct ClearIslandTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Clear Island Text"
    static var description: IntentDescription = IntentDescription("Removes your status and goes back to your preset.")

    func perform() async throws -> some IntentResult {
        await IslandManager.shared.setStatus(nil)
        return .result()
    }
}

// MARK: - Small bubble mode from Shortcuts

struct SetBubbleModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Small Bubble Mode"
    static var description: IntentDescription = IntentDescription("Turns stay-in-the-small-bubble mode on or off, so another app's Live Activity (like Uber Eats) can take the big spot. Hours of 0 means until you turn it off.")

    @Parameter(title: "On", default: true)
    var isOn: Bool

    @Parameter(title: "Turn off after (hours)", default: 2)
    var hours: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Small bubble mode \(\.$isOn) for \(\.$hours) hours")
    }

    func perform() async throws -> some IntentResult {
        await IslandManager.shared.setBubbleMode(isOn, hours: hours)
        return .result()
    }
}
