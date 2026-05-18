import SwiftUI

@main
struct YAMGApp: App {
    @StateObject private var preferences = AppPreferences()

    var body: some Scene {
        WindowGroup {
            RootShellView(preferences: preferences)
        }
    }
}
