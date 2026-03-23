import AuthenticationServices
import SwiftUI

struct OnboardingView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var pendingNonce = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("bubl")
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .foregroundStyle(BublPalette.ink)

            Text(String(localized: "onboarding.tagline"))
                .font(.bublRounded(.title3, weight: .medium))
                .foregroundStyle(BublPalette.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            SignInWithAppleButton(.signIn) { request in
                let nonce = authManager.makeNonce()
                pendingNonce = nonce
                request.requestedScopes = [.fullName]
                request.nonce = authManager.sha256(nonce)
            } onCompletion: { result in
                handleAuth(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 24)

            if let errorMessage {
                Text(errorMessage)
                    .font(.bublRounded(.footnote))
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .background(BublPalette.page.ignoresSafeArea())
    }

    private func handleAuth(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure:
            errorMessage = String(localized: "auth.error")
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = String(localized: "auth.error")
                return
            }

            Task {
                do {
                    try await authManager.signInWithApple(idToken: idToken, nonce: pendingNonce)
                } catch {
                    errorMessage = String(localized: "auth.error")
                }
            }
        }
    }
}
