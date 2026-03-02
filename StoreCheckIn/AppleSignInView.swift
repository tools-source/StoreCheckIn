import AuthenticationServices
import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var authController: AppAuthController

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)

                    Text("Store Check In")
                        .font(.largeTitle.bold())

                    Text("Sign in with Apple to access your account. Billing is handled separately through your App Store subscription.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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
}
