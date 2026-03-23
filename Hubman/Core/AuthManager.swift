import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Supabase

@Observable
final class AuthManager {
    enum State {
        case loading
        case signedOut
        case signedIn
    }

    private(set) var state: State = .loading
    private(set) var session: Session?
    private(set) var userLocale: String = Locale.current.language.languageCode?.identifier ?? "en"

    private let client = SupabaseConfig.client

    func restoreSession() async {
        do {
            let current = try await client.auth.session
            session = current
            state = .signedIn
            try await bootstrapUserIfNeeded(userID: current.user.id)
        } catch {
            state = .signedOut
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Non-fatal for local state reset.
        }
        session = nil
        state = .signedOut
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        let newSession = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        session = newSession
        state = .signedIn
        try await bootstrapUserIfNeeded(userID: newSession.user.id)
    }

    func bootstrapUserIfNeeded(userID: UUID) async throws {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        userLocale = locale

        try await client
            .from("users")
            .upsert([
                "id": AnyJSON.string(userID.uuidString),
                "locale": AnyJSON.string(locale)
            ])
            .execute()
    }

    func makeNonce() -> String {
        let bytes: [UInt8] = (0..<32).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
    }

    func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
