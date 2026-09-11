import AuthenticationServices
import Foundation

/// Google through the system browser, not a bundled SDK.
///
/// The backend hands back an authorize URL (Supabase's `/auth/v1/authorize?provider=google`
/// with `redirect_to=vlogify://auth/google`); `ASWebAuthenticationSession` shows it in
/// a Safari sheet and returns the callback. No client secret ever lives in the app,
/// and there is no Google SDK to carry a privacy manifest for. The mock's authorize
/// URL is already a `vlogify://` URL, so it completes without a browser.
@MainActor
final class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    func run(authorizeURL: URL) async throws -> URL {
        if authorizeURL.scheme == "vlogify" { return authorizeURL }
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authorizeURL, callbackURLScheme: "vlogify") { url, error in
                if let url { continuation.resume(returning: url) } else { continuation.resume(throwing: error ?? ASWebAuthenticationSessionError(.canceledLogin)) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
