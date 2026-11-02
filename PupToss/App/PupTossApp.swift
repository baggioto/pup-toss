import SwiftUI

@main
struct PupTossApp: App {
    init() {
        #if DEBUG
        IconExporter.exportIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
