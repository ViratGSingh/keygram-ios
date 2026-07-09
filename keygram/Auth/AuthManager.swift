import Foundation
import Combine
import CryptoKit
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Owns sign-in state for cloud backup. Apple + Google both resolve to a single Firebase
/// user; accounts that share a real email auto-link, and "Hide My Email" users can link a
/// second provider explicitly via `linkWithApple()` / `linkWithGoogle()`.
///
/// All provider/Firebase code is wrapped in `canImport` guards so the app compiles before
/// the Firebase and GoogleSignIn SPM packages are added; until then `isBackupAvailable` is
/// `false` and the sign-in methods surface a "not configured" message.
@MainActor
final class AuthManager: ObservableObject {
    struct Account: Equatable {
        var uid: String
        var email: String?
        var displayName: String?
        /// Firebase provider IDs currently linked, e.g. `apple.com`, `google.com`.
        var providers: [String]
    }

    enum AuthState: Equatable {
        case signedOut
        case signedIn(Account)
    }

    static let shared = AuthManager()

    @Published private(set) var state: AuthState = .signedOut
    @Published private(set) var isWorking = false
    @Published var lastError: String?

    /// True only once the Firebase SDK is linked into the build.
    var isBackupAvailable: Bool {
        #if canImport(FirebaseAuth)
        true
        #else
        false
        #endif
    }

    var account: Account? {
        if case let .signedIn(account) = state { return account }
        return nil
    }

    private var appleCoordinator: AppleSignInCoordinator?
    /// A credential from a provider that collided with an existing account, held until the
    /// user re-authenticates with the existing provider so we can link them.
    private var pendingLinkCredential: PendingCredential?

    private init() {
        refreshFromFirebase()
    }

    /// Reflect Firebase's current user into `state` (call at launch, after `configure()`).
    func refreshFromFirebase() {
        #if canImport(FirebaseAuth)
        state = Self.account(from: Auth.auth().currentUser).map(AuthState.signedIn) ?? .signedOut
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
        #endif
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
        pendingLinkCredential = nil
        state = .signedOut
    }

    // MARK: - Sign in

    func signInWithApple() {
        startAppleFlow(mode: .signIn)
    }

    func signInWithGoogle() {
        Task { await runGoogleFlow(mode: .signIn) }
    }

    // MARK: - Linking (manual cross-provider fallback for Hide My Email)

    func linkWithApple() {
        startAppleFlow(mode: .link)
    }

    func linkWithGoogle() {
        Task { await runGoogleFlow(mode: .link) }
    }

    // MARK: - Apple

    private enum FlowMode { case signIn, link }

    private func startAppleFlow(mode: FlowMode) {
        #if canImport(AuthenticationServices) && canImport(FirebaseAuth)
        let rawNonce = Self.randomNonce()
        let coordinator = AppleSignInCoordinator(hashedNonce: Self.sha256(rawNonce)) { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case let .success(idToken):
                    let credential = OAuthProvider.appleCredential(
                        withIDToken: idToken,
                        rawNonce: rawNonce,
                        fullName: nil
                    )
                    await self.completeFirebase(with: credential, mode: mode)
                case let .failure(error):
                    self.finish(error: error)
                }
                self.appleCoordinator = nil
            }
        }
        appleCoordinator = coordinator
        isWorking = true
        lastError = nil
        coordinator.start()
        #else
        surfaceUnavailable()
        #endif
    }

    // MARK: - Google

    private func runGoogleFlow(mode: FlowMode) async {
        #if canImport(GoogleSignIn) && canImport(FirebaseAuth)
        guard let presenter = Self.topViewController() else {
            finish(error: SimpleError(message: "No window available for Google sign-in."))
            return
        }
        isWorking = true
        lastError = nil
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                finish(error: SimpleError(message: "Google did not return an ID token."))
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            await completeFirebase(with: credential, mode: mode)
        } catch {
            finish(error: error)
        }
        #else
        surfaceUnavailable()
        #endif
    }

    // MARK: - Firebase completion + linking

    #if canImport(FirebaseAuth)
    private func completeFirebase(with credential: AuthCredential, mode: FlowMode) async {
        do {
            if mode == .link, let user = Auth.auth().currentUser {
                _ = try await user.link(with: credential)
            } else if let pending = pendingLinkCredential {
                // Second leg of an auto-link collision: signing in with the existing
                // provider, now link the credential we stashed earlier.
                let signIn = try await Auth.auth().signIn(with: credential)
                _ = try? await signIn.user.link(with: pending.credential)
                pendingLinkCredential = nil
            } else {
                _ = try await Auth.auth().signIn(with: credential)
            }
            finish(error: nil)
        } catch {
            handleFirebase(error: error, attempted: credential)
        }
    }

    private func handleFirebase(error: Error, attempted: AuthCredential) {
        let nsError = error as NSError
        if nsError.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
            // Same email already registered under another provider. Stash this credential
            // and ask the user to sign in with the provider they already have, then link.
            let email = nsError.userInfo[AuthErrorUserInfoEmailKey] as? String
            pendingLinkCredential = PendingCredential(credential: attempted, email: email)
            let hint = email.map { " for \($0)" } ?? ""
            finish(error: SimpleError(
                message: "You already have a Keygram account\(hint). Sign in with your other provider to link them."
            ))
            return
        }
        finish(error: error)
    }

    private static func account(from user: User?) -> Account? {
        guard let user else { return nil }
        return Account(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            providers: user.providerData.map(\.providerID)
        )
    }
    #endif

    // MARK: - Helpers

    private func finish(error: Error?) {
        isWorking = false
        if let error {
            lastError = (error as? SimpleError)?.message ?? error.localizedDescription
        } else {
            lastError = nil
        }
        refreshFromFirebase()
    }

    private func surfaceUnavailable() {
        lastError = "Cloud backup isn't configured in this build yet."
        isWorking = false
    }

    private struct PendingCredential {
        #if canImport(FirebaseAuth)
        var credential: AuthCredential
        #endif
        var email: String?
    }

    struct SimpleError: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    // MARK: - Nonce

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    #if canImport(UIKit)
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
    #else
    private static func topViewController() -> Never? { nil }
    #endif
}

#if canImport(AuthenticationServices)
/// Bridges `ASAuthorizationController`'s delegate callbacks to a completion handler and
/// keeps itself alive for the duration of the request.
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private let hashedNonce: String
    private let completion: (Result<String, Error>) -> Void

    init(hashedNonce: String, completion: @escaping (Result<String, Error>) -> Void) {
        self.hashedNonce = hashedNonce
        self.completion = completion
    }

    func start() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8)
        else {
            completion(.failure(AuthManager.SimpleError(message: "Apple sign-in returned no token.")))
            return
        }
        completion(.success(token))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
#endif
