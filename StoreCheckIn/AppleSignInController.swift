import AuthenticationServices
import Foundation

struct AppUserSession: Equatable {
    let userID: String
    let displayName: String?
    let email: String?
}

@MainActor
final class AppAuthController: ObservableObject {
    enum ReauthenticationResult {
        case success
        case cancelled
        case failure(String)
    }

    @Published private(set) var isChecking = false
    @Published private(set) var session: AppUserSession?
    @Published var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let appleProvider = ASAuthorizationAppleIDProvider()

    private enum StorageKey {
        static let provider = "auth.provider"
        static let userID = "appleSignIn.userID"
        static let displayName = "appleSignIn.displayName"
        static let email = "appleSignIn.email"
    }

    init() {
        clearLegacyManualAuthDataIfNeeded()
        session = loadPersistedSession()

        if session != nil {
            isChecking = true
            Task {
                await refreshSessionState()
            }
        }
    }

    var isSignedIn: Bool {
        session != nil
    }

    var accountSummary: String {
        if let displayName = session?.displayName, !displayName.isEmpty {
            return displayName
        }

        if let email = session?.email, !email.isEmpty {
            return email
        }

        return "Apple account connected"
    }

    var resetPinAccountLabel: String {
        if let displayName = session?.displayName, !displayName.isEmpty {
            return displayName
        }

        if let email = session?.email, !email.isEmpty {
            return email
        }

        return "Signed in with Apple on this device"
    }

    var shouldShowResetPinAccountHint: Bool {
        guard let session else { return true }
        let hasDisplayName = !(session.displayName?.isEmpty ?? true)
        let hasEmail = !(session.email?.isEmpty ?? true)
        return !hasDisplayName && !hasEmail
    }

    var providerSummary: String {
        switch session {
        case .some:
            return "Signed in with Apple"
        case nil:
            return "Signed out"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handleAppleAuthorizationResult(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Apple Sign In did not return a valid credential."
                session = nil
                return
            }

            let updatedSession = AppUserSession(
                userID: credential.user,
                displayName: formattedName(from: credential.fullName) ?? session?.displayName,
                email: credential.email ?? session?.email
            )

            persist(updatedSession)
            session = updatedSession
            errorMessage = nil

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
            session = loadPersistedSession()
        }

        isChecking = false
    }

    func handleAppleReauthenticationResult(_ result: Result<ASAuthorization, any Error>) -> ReauthenticationResult {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return .failure("Apple Sign In did not return a valid credential.")
            }

            guard let currentSession = session ?? loadPersistedSession() else {
                return .failure("Your Apple account session is unavailable. Sign in again to reset the PIN.")
            }

            guard credential.user == currentSession.userID else {
                return .failure("Use the same Apple account currently signed into this app.")
            }

            let refreshedSession = AppUserSession(
                userID: currentSession.userID,
                displayName: formattedName(from: credential.fullName) ?? currentSession.displayName,
                email: credential.email ?? currentSession.email
            )

            persist(refreshedSession)
            session = refreshedSession
            return .success

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return .cancelled
            }

            return .failure(error.localizedDescription)
        }
    }

    func refreshSessionState(showsLoadingState: Bool = true) async {
        guard let persistedSession = loadPersistedSession() else {
            session = nil
            errorMessage = nil
            isChecking = false
            return
        }

        if showsLoadingState {
            isChecking = true
        }

        do {
            let state = try await credentialState(for: persistedSession.userID)

            switch state {
            case .authorized, .transferred:
                session = persistedSession
                errorMessage = nil
            case .revoked, .notFound:
                clearPersistedSession()
                errorMessage = nil
            @unknown default:
                clearPersistedSession()
                errorMessage = "Apple account status could not be verified."
            }
        } catch {
            session = persistedSession
            errorMessage = nil
        }

        if showsLoadingState {
            isChecking = false
        }
    }

    func signOut() {
        clearPersistedSession()
        errorMessage = nil
        isChecking = false
    }

    private func loadPersistedSession() -> AppUserSession? {
        if defaults.string(forKey: StorageKey.provider) == "manual" {
            return nil
        }

        guard let userID = defaults.string(forKey: StorageKey.userID), !userID.isEmpty else {
            return nil
        }

        let displayName = defaults.string(forKey: StorageKey.displayName)
        let email = defaults.string(forKey: StorageKey.email)

        return AppUserSession(
            userID: userID,
            displayName: displayName,
            email: email
        )
    }

    private func persist(_ session: AppUserSession) {
        defaults.removeObject(forKey: StorageKey.provider)
        defaults.set(session.userID, forKey: StorageKey.userID)
        defaults.set(session.displayName, forKey: StorageKey.displayName)
        defaults.set(session.email, forKey: StorageKey.email)
    }

    private func clearPersistedSession() {
        defaults.removeObject(forKey: StorageKey.provider)
        defaults.removeObject(forKey: StorageKey.userID)
        defaults.removeObject(forKey: StorageKey.displayName)
        defaults.removeObject(forKey: StorageKey.email)
        session = nil
    }

    private func clearLegacyManualAuthDataIfNeeded() {
        if defaults.string(forKey: StorageKey.provider) == "manual" {
            clearPersistedSession()
        }
    }

    private func formattedName(from nameComponents: PersonNameComponents?) -> String? {
        guard let nameComponents else { return nil }

        let formatter = PersonNameComponentsFormatter()
        let formatted = formatter.string(from: nameComponents).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }

    private func credentialState(for userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        try await withCheckedThrowingContinuation { continuation in
            appleProvider.getCredentialState(forUserID: userID) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }
}
