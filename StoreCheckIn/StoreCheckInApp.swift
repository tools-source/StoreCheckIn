import SwiftUI
import SwiftData

@main
struct StoreCheckInApp: App {
    var body: some Scene {
        WindowGroup {
            TimeClockRootView()
        }
        .modelContainer(for: LocalTimeClockModule.models)
    }
}
