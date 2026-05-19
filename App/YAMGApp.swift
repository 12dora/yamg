import SwiftUI

@main
struct YAMGApp: App {
    @StateObject private var preferences = AppPreferences()
    @StateObject private var logStore = ProcessLogStore()

    var body: some Scene {
        WindowGroup {
            RootShellView(preferences: preferences, logStore: logStore)
                .environment(\.locale, preferences.preferredLanguage.locale)
        }
    }
}
