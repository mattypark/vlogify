import AuthenticationServices
import SwiftUI
import VlogifyContract
import VlogifyDesign

/// The one paper screen. Doodles around a mascot, the tagline, three ways in.
struct WelcomeView: View {
    @Environment(AppState.self) private var state
    @State private var showEmail = false
    @State private var busy: AuthProviderKind?
    private let apple = AppleSignIn()
    private let google = GoogleSignIn()

    var body: some View {
        ZStack {
            Color.chalk.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                DoodleSticker(.camcorder, animated: true)
                    .padding(.bottom, Space.lg)
                Wordmark(onPaper: true, size: 34)
                Text("new moment every hour,\nvlog it with your friends.")
                    .font(.vlogBody)
                    .foregroundStyle(Color.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, Space.xs)
                Spacer()
                Spacer()
                VStack(spacing: Space.sm) {
                    // Apple's own button (4.8 requires it), wearing the sticker outline
                    // and shadow so it belongs to the page.
                    SignInWithAppleButton(.continue) { _ in } onCompletion: { _ in }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 56)
                        .clipShape(Capsule())
                        .sticker(fill: .text, corner: .capsule)
                        .overlay(Capsule().fill(Color.black.opacity(0.001)).onTapGesture { signInWithApple() })
                        .stickerRoom()
                        .accessibilityIdentifier("welcome.apple")
                    ChunkyButton(title: "Continue with Google", icon: "g.circle.fill", fill: .card, ink: .text, isLoading: busy == .google) { signInWithGoogle() }
                        .accessibilityIdentifier("welcome.google")
                    Button { showEmail = true } label: {
                        Text("Continue with email")
                            .font(.vlogLabel)
                            .foregroundStyle(Color.text)
                            .underline()
                            .frame(height: Metrics.hitTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("welcome.email")
                    if BackendRoot.usesMock {
                        // Only while the app runs on the mock: walks the whole
                        // onboarding without an email in the loop. Disappears the day
                        // a Secrets.xcconfig points at a real backend.
                        Button { skip() } label: {
                            Text("skip for now")
                                .font(.vlogCaption)
                                .foregroundStyle(Color.textSoft)
                                .frame(height: Metrics.hitTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("welcome.skip")
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xxl)
            }
        }
        .tapBursts()
        .sheet(isPresented: $showEmail) { EmailSignInSheet() }
        .toastOverlay(state.toast)
    }

    private func signInWithApple() {
        guard busy == nil else { return }
        busy = .apple
        Task {
            defer { busy = nil }
            do {
                let result: AppleSignIn.Result
                if BackendRoot.usesMock {
                    // The mock does not verify tokens, and the Apple sheet cannot be
                    // driven by the walker: skip straight to the exchange.
                    result = AppleSignIn.Result(identityToken: "mock", nonce: "mock", authorizationCode: nil, fullName: nil)
                } else {
                    result = try await apple.signIn()
                }
                let session = try await state.backend.auth.signInWithApple(
                    identityToken: result.identityToken, nonce: result.nonce,
                    authorizationCode: result.authorizationCode, fullName: result.fullName)
                MockSessionStore.save(.solo)
                Haptics.success()
                await state.didSignIn(session)
            } catch is ASAuthorizationError {
                // Cancelled. Nothing to say.
            } catch {
                state.show(.error(String(localized: "couldn't sign in. try again.", bundle: .app)))
            }
        }
    }

    private func skip() {
        guard busy == nil else { return }
        Task {
            let session = try? await state.backend.auth.signInWithApple(identityToken: "skip", nonce: "skip", authorizationCode: nil, fullName: nil)
            guard let session else { return }
            MockSessionStore.save(.solo)
            await state.didSignIn(session)
        }
    }

    private func signInWithGoogle() {
        guard busy == nil else { return }
        busy = .google
        Task {
            defer { busy = nil }
            do {
                let url = try await state.backend.auth.beginGoogleSignIn()
                let callback = try await google.run(authorizeURL: url)
                let session = try await state.backend.auth.completeGoogleSignIn(callback: callback)
                MockSessionStore.save(.solo)
                Haptics.success()
                await state.didSignIn(session)
            } catch is ASWebAuthenticationSessionError {
                // Cancelled.
            } catch {
                state.show(.error(String(localized: "couldn't sign in. try again.", bundle: .app)))
            }
        }
    }
}
