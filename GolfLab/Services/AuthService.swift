import AuthenticationServices
import Supabase
import SwiftUI

@MainActor
class AuthService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var errorMessage: String?

    static let shared = AuthService()

    private override init() {
        super.init()
    }

    func checkSession() async {
        do {
            _ = try await SupabaseService.shared.client.auth.session
            isAuthenticated = true
        } catch {
            isAuthenticated = false
        }
        isLoading = false
    }

    func signInWithApple() async {
        errorMessage = nil
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate()

        do {
            let credential = try await delegate.performRequest(controller)

            guard let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8)
            else {
                errorMessage = "Unable to get identity token from Apple."
                return
            }

            var fullName: PersonNameComponents? = nil
            if let firstName = credential.fullName?.givenName,
               let lastName = credential.fullName?.familyName {
                fullName = PersonNameComponents()
                fullName?.givenName = firstName
                fullName?.familyName = lastName
            }

            try await SupabaseService.shared.client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString,
                    nonce: nil
                )
            )
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await SupabaseService.shared.client.auth.signOut()
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var currentUserId: UUID? {
        get async {
            try? await SupabaseService.shared.client.auth.session.user.id
        }
    }
}

// MARK: - ASAuthorizationController async bridge

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func performRequest(_ controller: ASAuthorizationController) async throws -> ASAuthorizationAppleIDCredential {
        controller.delegate = self
        controller.presentationContextProvider = self
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthError.invalidCredential)
            return
        }
        continuation?.resume(returning: credential)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

enum AuthError: LocalizedError {
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid Apple credential received."
        }
    }
}
