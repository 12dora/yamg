import SwiftUI

@main
struct YAMGApp: App {
    @StateObject private var preferences = AppPreferences()
    @StateObject private var logStore = ProcessLogStore()

    var body: some Scene {
        WindowGroup(LocalizationKey.appTitle.localizedStringKey) {
            RootShellView(preferences: preferences, logStore: logStore)
                .environment(\.locale, preferences.preferredLanguage.locale)
        }

        Settings {
            PreferencesView(preferences: preferences)
                .environment(\.locale, preferences.preferredLanguage.locale)
                .padding(20)
                .frame(width: 540)
        }
    }
}
