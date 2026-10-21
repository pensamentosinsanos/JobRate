//
//  JobRateApp.swift
//  JobRate
//

import SwiftUI
import FirebaseCore

@main
struct JobRateApp: App {

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
