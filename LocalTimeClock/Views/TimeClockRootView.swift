import SwiftUI

struct TimeClockRootView: View {
    private static let entitlementRefreshInterval: Duration = .seconds(15)

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
                await authController.refreshSessionState(showsLoadingState: false)
                await subscriptionController.refreshEntitlements()
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }

            while !Task.isCancelled {
                await subscriptionController.refreshEntitlements()

                do {
                    try await Task.sleep(for: Self.entitlementRefreshInterval)
                } catch {
                    break
                }
            }
        }
    }

}
