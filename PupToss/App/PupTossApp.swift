import SwiftUI

@main
struct PupTossApp: App {
    init() {
        #if DEBUG
        IconExporter.exportIfRequested()
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            // A clean start for UI tests: no saved round to continue.
            SaveStore.clear()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
