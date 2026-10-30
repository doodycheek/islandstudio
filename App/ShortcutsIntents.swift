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
    }
}
