import SwiftUI
import SwiftData

@main
struct StoreCheckInApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var notificationAppDelegate
    @StateObject private var authController = AppAuthController()
    @StateObject private var subscriptionController = SubscriptionController()
    private let modelContainer = LocalTimeClockModule.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            TimeClockRootView()
                .environmentObject(authController)
                .environmentObject(subscriptionController)
        }
        .modelContainer(modelContainer)
    }
}
