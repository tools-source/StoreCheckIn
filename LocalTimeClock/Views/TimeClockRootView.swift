import SwiftUI

struct TimeClockRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authController: AppAuthController
    @EnvironmentObject private var subscriptionController: SubscriptionController

    var body: some View {
        Group {
            if authController.isChecking || (authController.isSignedIn && subscriptionController.isLoading) {
                ProgressView("Checking Apple account…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else if !authController.isSignedIn {
                AuthenticationView()
            } else if subscriptionController.hasActiveSubscription {
                EmployeesView()
            } else {
                SubscriptionPaywallView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await authController.refreshSessionState()
                await subscriptionController.refreshEntitlements()
            }
        }
    }
}
