import SwiftUI
import FirebaseCore

@main
struct JobRateApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
