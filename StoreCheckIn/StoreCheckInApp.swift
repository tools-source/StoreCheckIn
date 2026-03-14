import SwiftUI
import SwiftData

@main
struct StoreCheckInApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var notificationAppDelegate
    @StateObject private var authController = AppAuthController()
    @StateObject private var pinLockController = PinLockController()
    @StateObject private var storeProfileController = StoreProfileController()
    @StateObject private var subscriptionController = SubscriptionController()
    private let modelContainer = LocalTimeClockModule.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            TimeClockRootView()
                .environmentObject(authController)
                .environmentObject(pinLockController)
                .environmentObject(storeProfileController)
                .environmentObject(subscriptionController)
        }
        .modelContainer(modelContainer)
    }
}
