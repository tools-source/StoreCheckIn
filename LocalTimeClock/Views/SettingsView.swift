import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authController: AppAuthController
    @EnvironmentObject private var pinLockController: PinLockController
    @EnvironmentObject private var storeProfileController: StoreProfileController
    @EnvironmentObject private var subscriptionController: SubscriptionController
    @Query(sort: \Employee.createdAt, order: .reverse) private var employees: [Employee]

    @State private var pinSheetMode: PinSheetMode?
    @State private var showDeleteAccount = false
    @State private var showDeleteAccountAgain = false

    private let subscriptionsURL = "https://apps.apple.com/account/subscriptions"
    private let privacyPolicyURL = "https://tools-source.github.io/StoreCheckIn/privacy.html"
    private let termsOfUseURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Status", value: authController.accountSummary)
                    LabeledContent("Sign-In", value: authController.providerSummary)

                    Button("Refresh Account Status") {
                        Task {
                            await authController.refreshSessionState()
                        }
                    }
                }

                Section("Subscription") {
                    LabeledContent("Plan", value: subscriptionController.statusSummary)

                    Button("Restore Purchases") {
                        Task {
                            await subscriptionController.restorePurchases()
                        }
                    }

                    Button("Manage Subscription") {
                        openLink(subscriptionsURL)
                    }
                }

                Section {
                    TextField("Store Name", text: storeNameBinding, prompt: Text("Add store name"))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                } header: {
                    Text("Store")
                } footer: {
                    Text("Shown on the Employees tab as \"[Store Name] Employees\".")
                }

                Section("Legal") {
                    Button("Privacy Policy") {
                        openLink(privacyPolicyURL)
                    }

                    Button("Terms of Use (EULA)") {
                        openLink(termsOfUseURL)
                    }
                }

                Section("App Lock") {
                    LabeledContent("PIN", value: pinLockController.isPinEnabled ? "Enabled" : "Off")

                    if pinLockController.isPinEnabled {
                        if pinLockController.biometricType == .none {
                            LabeledContent("Biometric Unlock", value: "Unavailable")
                        } else {
                            Toggle(isOn: biometricUnlockBinding) {
                                Label(pinLockController.biometricType.title, systemImage: pinLockController.biometricType.systemImage)
                            }
                        }

                        Button("Change PIN") {
                            pinSheetMode = .change
                        }

                        Button("Turn Off PIN", role: .destructive) {
                            pinSheetMode = .disable
                        }
                    } else {
                        Button("Set 6-Digit PIN") {
                            pinSheetMode = .create
                        }
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await ShiftReminderScheduler.removeAllEmployeeReminders()
                        }
                        authController.signOut()
                    }

                    Button("Delete Account", role: .destructive) {
                        showDeleteAccount = true
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $pinSheetMode) { mode in
                PinManagementSheet(mode: mode)
            }
            .alert("Delete account from this device?", isPresented: $showDeleteAccount) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) {
                    showDeleteAccountAgain = true
                }
            } message: {
                Text("This removes all employees, archived hours, reminders, and store settings for the signed-in Apple account on this device.")
            }
            .alert("Final confirmation", isPresented: $showDeleteAccountAgain) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive) {
                    deleteCurrentAccount()
                }
            } message: {
                Text("Your App Store subscription stays on your Apple account, but this app's local account data will be deleted and you will be signed out.")
            }
            .onAppear {
                pinLockController.refreshStoredState()
            }
        }
    }

    private var biometricUnlockBinding: Binding<Bool> {
        Binding(
            get: { pinLockController.isBiometricUnlockEnabled },
            set: { _ = pinLockController.setBiometricUnlockEnabled($0) }
        )
    }

    private var storeNameBinding: Binding<String> {
        Binding(
            get: { storeProfileController.storeName },
            set: { storeProfileController.updateStoreName($0) }
        )
    }

    private var currentUserID: String? {
        authController.session?.userID
    }

    private func deleteCurrentAccount() {
        guard let currentUserID else { return }

        employees
            .filter { $0.ownerUserID == currentUserID }
            .forEach(context.delete)

        try? context.save()
        storeProfileController.clearStoreName(for: currentUserID)

        Task {
            await ShiftReminderScheduler.removeAllEmployeeReminders()
        }

        authController.signOut()
    }

    private func openLink(_ rawURL: String) {
        guard let url = URL(string: rawURL) else { return }
        openURL(url)
    }
}

private enum PinSheetMode: String, Identifiable {
    case create
    case change
    case disable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .create:
            return "Set PIN"
        case .change:
            return "Change PIN"
        case .disable:
            return "Turn Off PIN"
        }
    }
}

private struct PinManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pinLockController: PinLockController

    let mode: PinSheetMode

    @State private var currentPin = ""
    @State private var newPin = ""
    @State private var confirmPin = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(descriptionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if mode != .create {
                    Section("Current PIN") {
                        PinFormField(title: "Enter Current PIN", pin: $currentPin)
                    }
                }

                if mode != .disable {
                    Section(mode == .create ? "New PIN" : "Replace With") {
                        PinFormField(title: "Enter New 6-Digit PIN", pin: $newPin)
                        PinFormField(title: "Confirm New PIN", pin: $confirmPin)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(actionButtonTitle) {
                        submit()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private var descriptionText: String {
        switch mode {
        case .create:
            return "Create a 6-digit PIN to lock the app when it opens again."
        case .change:
            return "Enter your current PIN, then choose a new 6-digit PIN."
        case .disable:
            return "Enter your current PIN to turn off the app lock."
        }
    }

    private var actionButtonTitle: String {
        switch mode {
        case .create:
            return "Save"
        case .change:
            return "Update"
        case .disable:
            return "Turn Off"
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .create:
            return PinLockController.isValid(pin: newPin) && newPin == confirmPin
        case .change:
            return PinLockController.isValid(pin: currentPin) && PinLockController.isValid(pin: newPin) && newPin == confirmPin
        case .disable:
            return PinLockController.isValid(pin: currentPin)
        }
    }

    private func submit() {
        errorMessage = nil

        switch mode {
        case .create:
            guard newPin == confirmPin else {
                errorMessage = "The new PINs do not match."
                return
            }

            guard pinLockController.setPin(newPin) else {
                errorMessage = "PIN must be exactly 6 numbers."
                return
            }

        case .change:
            guard newPin == confirmPin else {
                errorMessage = "The new PINs do not match."
                return
            }

            guard pinLockController.changePin(currentPin: currentPin, newPin: newPin) else {
                errorMessage = "Current PIN is incorrect."
                return
            }

        case .disable:
            guard pinLockController.disablePin(currentPin: currentPin) else {
                errorMessage = "Current PIN is incorrect."
                return
            }
        }

        dismiss()
    }
}

private struct PinFormField: View {
    let title: String
    @Binding var pin: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            SecureField("6 digits", text: binding)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
        }
        .padding(.vertical, 4)
    }

    private var binding: Binding<String> {
        Binding(
            get: { pin },
            set: { pin = PinLockController.normalize($0) }
        )
    }
}
