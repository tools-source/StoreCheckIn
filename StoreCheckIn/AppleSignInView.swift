import AuthenticationServices
import SwiftUI

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn = "Log In"
    case signUp = "Sign Up"

    var id: String { rawValue }
}

struct AuthenticationView: View {
    @EnvironmentObject private var authController: AppAuthController

    @State private var mode: AuthMode = .signIn
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)

                    Text("Store Check In")
                        .font(.largeTitle.bold())

                    Text("Use Apple Sign In or create an email account. Billing is handled separately through your App Store subscription.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Picker("Authentication Mode", selection: $mode) {
                    ForEach(AuthMode.allCases) { authMode in
                        Text(authMode.rawValue).tag(authMode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in
                    authController.clearError()
                }

                VStack(spacing: 14) {
                    if mode == .signUp {
                        TextField("Full Name", text: $displayName)
                            .textContentType(.name)
                    }

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)

                    SecureField("Password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)

                    if mode == .signUp {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }

                    Button(actionTitle, action: submit)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(isSubmitDisabled)
                }
                .textFieldStyle(.roundedBorder)

                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 1)
                    Text("or")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 1)
                }

                SignInWithAppleButton(.signIn) { request in
                    authController.configureAppleRequest(request)
                } onCompletion: { result in
                    authController.handleAppleAuthorizationResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let errorMessage = authController.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var actionTitle: String {
        mode == .signIn ? "Log In with Email" : "Create Account"
    }

    private var isSubmitDisabled: Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode == .signIn {
            return cleanEmail.isEmpty || password.isEmpty
        }

        return displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || cleanEmail.isEmpty
            || password.isEmpty
            || confirmPassword.isEmpty
    }

    private func submit() {
        authController.clearError()

        if mode == .signUp {
            guard password == confirmPassword else {
                authController.errorMessage = "Passwords do not match."
                return
            }

            authController.signUpManually(
                displayName: displayName,
                email: email,
                password: password
            )
        } else {
            authController.signInManually(email: email, password: password)
        }
    }
}
