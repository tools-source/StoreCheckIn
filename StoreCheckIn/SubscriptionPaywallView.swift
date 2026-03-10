import SwiftUI

struct SubscriptionPaywallView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authController: AppAuthController
    @EnvironmentObject private var subscriptionController: SubscriptionController
    private let subscriptionsURL = "https://apps.apple.com/account/subscriptions"
    private let privacyPolicyURL = "https://tools-source.github.io/StoreCheckIn/privacy.html"
    private let termsOfUseURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

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
                    Text("Subscription Details")
                        .font(.headline)

                    detailRow(label: "Title", value: subscriptionController.planName)
                    detailRow(label: "Length", value: "1 month (auto-renewing)")
                    detailRow(label: "Price", value: "\(subscriptionController.monthlyDisplayPrice) per month")

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
                        openLink(subscriptionsURL)
                    }
                    .buttonStyle(.bordered)

                    Button("Privacy Policy") {
                        openLink(privacyPolicyURL)
                    }
                    .buttonStyle(.bordered)

                    Button("Terms of Use (EULA)") {
                        openLink(termsOfUseURL)
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

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private func openLink(_ rawURL: String) {
        guard let url = URL(string: rawURL) else { return }
        openURL(url)
    }
}
