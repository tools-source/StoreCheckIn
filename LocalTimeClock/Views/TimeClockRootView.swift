import SwiftUI
import CryptoKit
import LocalAuthentication
import AuthenticationServices

struct TimeClockRootView: View {
    private static let entitlementRefreshInterval: Duration = .seconds(15)

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authController: AppAuthController
    @EnvironmentObject private var pinLockController: PinLockController
    @EnvironmentObject private var storeProfileController: StoreProfileController
    @EnvironmentObject private var subscriptionController: SubscriptionController

    var body: some View {
        ZStack {
            content
                .blur(radius: shouldShowPinLock ? 8 : 0)
                .allowsHitTesting(!shouldShowPinLock)

            if shouldShowPinLock {
                PinLockView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: shouldShowPinLock)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background, authController.isSignedIn {
                pinLockController.lock()
            }

            guard newPhase == .active else { return }
            pinLockController.refreshStoredState()
            Task {
                await authController.refreshSessionState(showsLoadingState: false)
                await subscriptionController.refreshEntitlements()
            }
        }
        .onChange(of: authController.isSignedIn) { _, isSignedIn in
            guard isSignedIn, pinLockController.isPinEnabled else { return }
            pinLockController.lock()
        }
        .onChange(of: authController.session?.userID) { _, userID in
            storeProfileController.refresh(for: userID)
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
        .task {
            storeProfileController.refresh(for: authController.session?.userID)
        }
    }

    private var content: some View {
        Group {
            if authController.isChecking || (authController.isSignedIn && subscriptionController.isLoading) {
                ProgressView("Checking Apple account…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else if !authController.isSignedIn {
                AuthenticationView()
            } else if subscriptionController.hasActiveSubscription {
                LocalTimeClockTabView()
            } else {
                SubscriptionPaywallView()
            }
        }
    }

    private var shouldShowPinLock: Bool {
        authController.isSignedIn && pinLockController.isPinEnabled && pinLockController.isLocked
    }
}

@MainActor
final class StoreProfileController: ObservableObject {
    @Published private(set) var storeName = ""

    private let defaults = UserDefaults.standard
    private let storeNameKeyPrefix = "store_check_in.store_name"
    private var currentUserID: String?

    var employeesTitle: String {
        storeName.isEmpty ? "Employees" : "\(storeName) Employees"
    }

    func refresh(for userID: String?) {
        currentUserID = userID
        storeName = storedStoreName(for: userID)
    }

    func updateStoreName(_ value: String) {
        let normalizedValue = normalizedStoreName(value)
        storeName = normalizedValue

        guard let currentUserID else { return }

        let key = storeNameKey(for: currentUserID)
        if normalizedValue.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(normalizedValue, forKey: key)
        }
    }

    func clearStoreName(for userID: String?) {
        guard let userID else {
            if currentUserID == nil {
                storeName = ""
            }
            return
        }

        defaults.removeObject(forKey: storeNameKey(for: userID))

        if currentUserID == userID {
            storeName = ""
        }
    }

    private func storedStoreName(for userID: String?) -> String {
        guard let userID else { return "" }
        return normalizedStoreName(defaults.string(forKey: storeNameKey(for: userID)) ?? "")
    }

    private func storeNameKey(for userID: String) -> String {
        "\(storeNameKeyPrefix).\(userID)"
    }

    private func normalizedStoreName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
final class PinLockController: ObservableObject {
    static let pinLength = 6

    enum BiometricType {
        case none
        case faceID
        case touchID

        var title: String {
            switch self {
            case .none:
                return "Biometric Unlock"
            case .faceID:
                return "Face ID"
            case .touchID:
                return "Touch ID"
            }
        }

        var buttonTitle: String {
            switch self {
            case .none:
                return "Use Biometrics"
            case .faceID:
                return "Use Face ID"
            case .touchID:
                return "Use Touch ID"
            }
        }

        var systemImage: String {
            switch self {
            case .none:
                return "person.crop.circle.badge.questionmark"
            case .faceID:
                return "faceid"
            case .touchID:
                return "touchid"
            }
        }
    }

    @Published private(set) var isPinEnabled = false
    @Published private(set) var isLocked = false
    @Published private(set) var biometricType: BiometricType = .none
    @Published private(set) var isBiometricUnlockEnabled = false

    private let defaults = UserDefaults.standard
    private let pinHashKey = "store_check_in_app_pin_hash"
    private let biometricUnlockEnabledKey = "store_check_in_biometric_unlock_enabled"

    init() {
        refreshStoredState()
        isLocked = isPinEnabled
    }

    func setPin(_ pin: String) -> Bool {
        let normalizedPin = Self.normalize(pin)
        guard Self.isValid(pin: normalizedPin) else { return false }

        defaults.set(hash(normalizedPin), forKey: pinHashKey)
        isPinEnabled = true
        refreshBiometricAvailability()
        isLocked = false
        return true
    }

    func changePin(currentPin: String, newPin: String) -> Bool {
        guard verify(pin: currentPin) else { return false }
        return setPin(newPin)
    }

    func disablePin(currentPin: String) -> Bool {
        guard verify(pin: currentPin) else { return false }

        defaults.removeObject(forKey: pinHashKey)
        defaults.removeObject(forKey: biometricUnlockEnabledKey)
        isPinEnabled = false
        isBiometricUnlockEnabled = false
        isLocked = false
        return true
    }

    func unlock(with pin: String) -> Bool {
        guard verify(pin: pin) else { return false }

        isLocked = false
        return true
    }

    func lock() {
        guard isPinEnabled else { return }
        isLocked = true
    }

    func refreshStoredState() {
        isPinEnabled = defaults.string(forKey: pinHashKey) != nil
        isBiometricUnlockEnabled = defaults.bool(forKey: biometricUnlockEnabledKey)
        refreshBiometricAvailability()

        if !isPinEnabled {
            defaults.removeObject(forKey: biometricUnlockEnabledKey)
            isBiometricUnlockEnabled = false
            isLocked = false
        }
    }

    @discardableResult
    func setBiometricUnlockEnabled(_ enabled: Bool) -> Bool {
        refreshBiometricAvailability()

        let shouldEnable = enabled && isPinEnabled && biometricType != .none
        defaults.set(shouldEnable, forKey: biometricUnlockEnabledKey)
        isBiometricUnlockEnabled = shouldEnable
        return shouldEnable == enabled
    }

    var canUseBiometricUnlock: Bool {
        isPinEnabled && isBiometricUnlockEnabled && biometricType != .none
    }

    func attemptBiometricUnlock() async -> Bool {
        guard canUseBiometricUnlock else { return false }

        let context = LAContext()
        context.localizedFallbackTitle = "Use PIN"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            refreshBiometricAvailability()
            return false
        }

        let reason = "Unlock Store Check-In."
        let success = await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }

        if success {
            isLocked = false
        }

        return success
    }

    static func normalize(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(pinLength))
    }

    static func isValid(pin: String) -> Bool {
        pin.count == pinLength && pin.allSatisfy(\.isNumber)
    }

    private func verify(pin: String) -> Bool {
        guard let storedHash = defaults.string(forKey: pinHashKey) else { return false }
        let normalizedPin = Self.normalize(pin)
        guard Self.isValid(pin: normalizedPin) else { return false }
        return storedHash == hash(normalizedPin)
    }

    private func refreshBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = canEvaluate ? Self.biometricType(for: context.biometryType) : .none
    }

    private func hash(_ pin: String) -> String {
        SHA256.hash(data: Data(pin.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func biometricType(for type: LABiometryType) -> BiometricType {
        switch type {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
}

private struct PinLockView: View {
    @EnvironmentObject private var authController: AppAuthController
    @EnvironmentObject private var pinLockController: PinLockController

    @State private var pin = ""
    @State private var errorMessage: String?
    @State private var isUnlockingWithBiometrics = false
    @State private var showForgotPinReset = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("App Locked")
                        .font(.title.bold())

                    Text(pinLockController.canUseBiometricUnlock ? "Use \(pinLockController.biometricType.title) or enter your 6-digit PIN." : "Enter your 6-digit PIN to continue.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if pinLockController.canUseBiometricUnlock {
                    Button {
                        Task {
                            await unlockWithBiometrics(showError: true)
                        }
                    } label: {
                        Label(pinLockController.biometricType.buttonTitle, systemImage: pinLockController.biometricType.systemImage)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUnlockingWithBiometrics)
                }

                SixDigitPinField(pin: $pin)

                Button("Unlock") {
                    unlock()
                }
                .buttonStyle(.borderedProminent)
                .disabled(pin.count != PinLockController.pinLength)

                Button("Forgot PIN?") {
                    showForgotPinReset = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .onChange(of: pin) { _, newValue in
            pin = PinLockController.normalize(newValue)

            if pin.count == PinLockController.pinLength {
                unlock()
            }
        }
        .task {
            await unlockWithBiometrics(showError: false)
        }
        .sheet(isPresented: $showForgotPinReset) {
            ForgotPinResetSheet()
        }
    }

    private func unlock() {
        guard pin.count == PinLockController.pinLength else { return }

        if pinLockController.unlock(with: pin) {
            pin = ""
            errorMessage = nil
        } else {
            errorMessage = "Wrong PIN. Try again."
            pin = ""
        }
    }

    private func unlockWithBiometrics(showError: Bool) async {
        guard pinLockController.canUseBiometricUnlock, !isUnlockingWithBiometrics else { return }

        isUnlockingWithBiometrics = true
        let success = await pinLockController.attemptBiometricUnlock()
        isUnlockingWithBiometrics = false

        if success {
            errorMessage = nil
        } else if showError {
            errorMessage = "\(pinLockController.biometricType.title) was not verified. Use your PIN to unlock."
        }
    }
}

private struct ForgotPinResetSheet: View {
    private enum Step {
        case verifyAppleAccount
        case createNewPin
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authController: AppAuthController
    @EnvironmentObject private var pinLockController: PinLockController

    @State private var step: Step = .verifyAppleAccount
    @State private var newPin = ""
    @State private var confirmPin = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch step {
                    case .verifyAppleAccount:
                        verifyAccountContent
                    case .createNewPin:
                        createPinContent
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reset PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var verifyAccountContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verify Your Apple Account")
                    .font(.title3.bold())

                Text("To reset the app PIN, sign in again with the same Apple account currently connected to Store Check-In.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if authController.session != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current account")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(authController.resetPinAccountLabel)
                        .font(.headline)

                    if authController.shouldShowResetPinAccountHint {
                        Text("Apple may not share the account name or email here. Continue with the same Apple account already used to sign in.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            SignInWithAppleButton(.continue) { request in
                authController.configureAppleRequest(request)
            } onCompletion: { result in
                switch authController.handleAppleReauthenticationResult(result) {
                case .success:
                    errorMessage = nil
                    step = .createNewPin
                case .cancelled:
                    errorMessage = nil
                case .failure(let message):
                    errorMessage = message
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var createPinContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create a New PIN")
                    .font(.title3.bold())

                Text("Your Apple account was verified. Enter a new 6-digit PIN to unlock and continue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                PinResetFormField(title: "New 6-Digit PIN", pin: $newPin)
                PinResetFormField(title: "Confirm New PIN", pin: $confirmPin)
            }

            Button("Save New PIN") {
                saveNewPin()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSaveNewPin)
        }
    }

    private var canSaveNewPin: Bool {
        PinLockController.isValid(pin: newPin) && newPin == confirmPin
    }

    private func saveNewPin() {
        errorMessage = nil

        guard newPin == confirmPin else {
            errorMessage = "The new PINs do not match."
            return
        }

        guard pinLockController.setPin(newPin) else {
            errorMessage = "PIN must be exactly 6 numbers."
            return
        }

        dismiss()
    }
}

struct SixDigitPinField: View {
    @Binding var pin: String
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)

            HStack(spacing: 10) {
                ForEach(0..<PinLockController.pinLength, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(index < pin.count ? Color.blue : Color(.separator).opacity(0.3), lineWidth: 1)
                        )
                        .frame(width: 42, height: 52)
                        .overlay(
                            Text(index < pin.count ? "•" : "")
                                .font(.title2.weight(.bold))
                        )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }
}

private struct PinResetFormField: View {
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
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: { pin },
            set: { pin = PinLockController.normalize($0) }
        )
    }
}
