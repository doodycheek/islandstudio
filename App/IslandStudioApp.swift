import SwiftUI

@main
struct IslandStudioApp: App {
    @StateObject private var manager = IslandManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { manager.appBecameActive() }
        }
    }
}
