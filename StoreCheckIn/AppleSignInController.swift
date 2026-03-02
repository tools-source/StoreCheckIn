import AuthenticationServices
import CryptoKit
import Foundation

enum AuthProvider: String, Codable {
    case apple
    case manual
}

struct AppUserSession: Equatable {
    let provider: AuthProvider
    let userID: String
    let displayName: String?
    let email: String?
}

private struct ManualAccount: Codable, Equatable {
    let displayName: String
    let email: String
    let passwordHash: String
    let createdAt: Date
}

@MainActor
final class AppAuthController: ObservableObject {
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
        static let manualAccounts = "auth.manualAccounts"
    }

    init() {
        session = loadPersistedSession()

        if session?.provider == .apple {
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

        return session?.provider == .manual ? "Manual account connected" : "Apple account connected"
    }

    var providerSummary: String {
        switch session?.provider {
        case .apple:
            return "Signed in with Apple"
        case .manual:
            return "Signed in with email"
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
                provider: .apple,
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

    func signUpManually(displayName: String, email: String, password: String) {
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = normalizeEmail(email)

        guard !cleanName.isEmpty else {
            errorMessage = "Enter your name to create an account."
            return
        }

        guard isValidEmail(cleanEmail) else {
            errorMessage = "Enter a valid email address."
            return
        }

        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        var accounts = loadManualAccounts()
        guard !accounts.contains(where: { $0.email == cleanEmail }) else {
            errorMessage = "An account with that email already exists."
            return
        }

        let account = ManualAccount(
            displayName: cleanName,
            email: cleanEmail,
            passwordHash: passwordHash(for: password, email: cleanEmail),
            createdAt: Date.now
        )

        accounts.append(account)
        saveManualAccounts(accounts)

        let newSession = AppUserSession(
            provider: .manual,
            userID: cleanEmail,
            displayName: cleanName,
            email: cleanEmail
        )

        persist(newSession)
        session = newSession
        errorMessage = nil
        isChecking = false
    }

    func signInManually(email: String, password: String) {
        let cleanEmail = normalizeEmail(email)
        let accounts = loadManualAccounts()

        guard let account = accounts.first(where: { $0.email == cleanEmail }) else {
            errorMessage = "No account was found for that email."
            return
        }

        guard account.passwordHash == passwordHash(for: password, email: cleanEmail) else {
            errorMessage = "Incorrect password."
            return
        }

        let restoredSession = AppUserSession(
            provider: .manual,
            userID: cleanEmail,
            displayName: account.displayName,
            email: account.email
        )

        persist(restoredSession)
        session = restoredSession
        errorMessage = nil
        isChecking = false
    }

    func refreshSessionState() async {
        guard let persistedSession = loadPersistedSession() else {
            session = nil
            errorMessage = nil
            isChecking = false
            return
        }

        guard persistedSession.provider == .apple else {
            session = persistedSession
            errorMessage = nil
            isChecking = false
            return
        }

        isChecking = true

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

        isChecking = false
    }

    func signOut() {
        clearPersistedSession()
        errorMessage = nil
        isChecking = false
    }

    private func loadPersistedSession() -> AppUserSession? {
        guard let userID = defaults.string(forKey: StorageKey.userID), !userID.isEmpty else {
            return nil
        }

        let rawProvider = defaults.string(forKey: StorageKey.provider)
        let provider = AuthProvider(rawValue: rawProvider ?? "") ?? .apple
        let displayName = defaults.string(forKey: StorageKey.displayName)
        let email = defaults.string(forKey: StorageKey.email)

        return AppUserSession(
            provider: provider,
            userID: userID,
            displayName: displayName,
            email: email
        )
    }

    private func persist(_ session: AppUserSession) {
        defaults.set(session.provider.rawValue, forKey: StorageKey.provider)
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

    private func loadManualAccounts() -> [ManualAccount] {
        guard let data = defaults.data(forKey: StorageKey.manualAccounts) else {
            return []
        }

        return (try? JSONDecoder().decode([ManualAccount].self, from: data)) ?? []
    }

    private func saveManualAccounts(_ accounts: [ManualAccount]) {
        guard let data = try? JSONEncoder().encode(accounts) else {
            return
        }

        defaults.set(data, forKey: StorageKey.manualAccounts)
    }

    private func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pieces = email.split(separator: "@")
        guard pieces.count == 2 else { return false }
        return pieces[1].contains(".")
    }

    private func passwordHash(for password: String, email: String) -> String {
        let payload = Data("StoreCheckIn|\(email)|\(password)".utf8)
        let digest = SHA256.hash(data: payload)
        return digest.map { String(format: "%02x", $0) }.joined()
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
