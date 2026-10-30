import AppIntents

/// Commands the island's buttons send to the app.
enum IslandCommand: Sendable {
    case next, previous, togglePause
}

// These intents are compiled into both the app and the widget (the widget needs them for its buttons),
// but iOS always runs LiveActivityIntents inside the app. ISLAND_APP is only defined for the app target.

struct NextPresetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Next Island Preset"
    static var description: IntentDescription = IntentDescription("Switches the Dynamic Island to your next preset.")

    init() {}

    func perform() async throws -> some IntentResult {
        #if ISLAND_APP
        await IslandManager.shared.handle(.next)
        #endif
        return .result()
    }
}

struct PreviousPresetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Previous Island Preset"
    static var description: IntentDescription = IntentDescription("Switches the Dynamic Island to your previous preset.")

    init() {}

    func perform() async throws -> some IntentResult {
        #if ISLAND_APP
        await IslandManager.shared.handle(.previous)
        #endif
        return .result()
    }
}

struct TogglePauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or Resume Island Animation"
    static var description: IntentDescription = IntentDescription("Pauses or resumes the Dynamic Island animations.")

    init() {}

    func perform() async throws -> some IntentResult {
        #if ISLAND_APP
        await IslandManager.shared.handle(.togglePause)
        #endif
        return .result()
    }
}
