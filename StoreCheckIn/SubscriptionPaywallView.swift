import SwiftUI

struct SubscriptionPaywallView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authController: AppAuthController
    @EnvironmentObject private var subscriptionController: SubscriptionController

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard.and.123")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)

                    Text("Unlock Store Check In")
                        .font(.largeTitle.bold())

                    Text("A monthly subscription is required to access the time clock.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(subscriptionController.planName)
                        .font(.title3.bold())

                    Text("\(subscriptionController.monthlyDisplayPrice) per month")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    Text("Charged through the App Store and managed with your Apple account on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await subscriptionController.purchaseMonthlyPlan()
                        }
                    } label: {
                        if subscriptionController.isPurchasing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Subscribe for \(subscriptionController.monthlyDisplayPrice)")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(subscriptionController.isPurchasing)

                    Button("Restore Purchases") {
                        Task {
                            await subscriptionController.restorePurchases()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Manage or Cancel Subscription") {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Sign Out") {
                        Task {
                            await ShiftReminderScheduler.removeAllEmployeeReminders()
                        }
                        authController.signOut()
                    }
                    .buttonStyle(.borderless)
                }
                .padding(20)
                .frame(maxWidth: 420, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                if let errorMessage = subscriptionController.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }
}
