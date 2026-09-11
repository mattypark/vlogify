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
            Color.paper.ignoresSafeArea()
            GeometryReader { proxy in
                doodleField(in: proxy.size)
            }
            VStack(spacing: 0) {
                Spacer()
                DoodleSticker(.mascot)
                    .padding(.bottom, Space.lg)
                Wordmark(onPaper: true, size: 34)
                Text("new moment every hour,\nvlog it with your friends.")
                    .font(.vlogBody)
                    .foregroundStyle(Color.soot)
                    .multilineTextAlignment(.center)
                    .padding(.top, Space.xs)
                Spacer()
                Spacer()
                VStack(spacing: Space.sm) {
                    SignInWithAppleButton(.continue) { _ in } onCompletion: { _ in }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 56)
                        .clipShape(Capsule())
                        .overlay(Capsule().fill(Color.black.opacity(0.001)).onTapGesture { signInWithApple() })
                        .accessibilityIdentifier("welcome.apple")
                    PillButton(title: "Continue with Google", icon: "g.circle.fill", isLoading: busy == .google) { signInWithGoogle() }
                        .accessibilityIdentifier("welcome.google")
                    Button { showEmail = true } label: {
                        Text("Continue with email")
                            .font(.vlogLabel)
                            .foregroundStyle(Color.soot)
                            .underline()
                            .frame(height: Metrics.hitTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("welcome.email")
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xxl + Space.xl)
            }
        }
        .sheet(isPresented: $showEmail) { EmailSignInSheet() }
        .toastOverlay(state.toast)
    }

    /// The stickers, placed by hand. Positions are fractions of the screen so the
    /// same scatter works on a 16e and a Pro Max.
    private func doodleField(in size: CGSize) -> some View {
        let w = size.width, h = size.height
        return ZStack {
            DoodleSticker(.sparkleSmall).position(x: w * 0.09, y: h * 0.12)
            DoodleSticker(.starHappy).position(x: w * 0.28, y: h * 0.12)
            DoodleSticker(.sparkleSmall).position(x: w * 0.54, y: h * 0.12)
            DoodleSticker(.starSurprised).position(x: w * 0.74, y: h * 0.13)
            DoodleSticker(.sparkleLarge).position(x: w * 0.9, y: h * 0.2)
            DoodleSticker(.envelope).position(x: w * 0.13, y: h * 0.3)
            DoodleSticker(.moon).position(x: w * 0.86, y: h * 0.3)
            DoodleSticker(.pizza).position(x: w * 0.17, y: h * 0.52)
            DoodleSticker(.orange).position(x: w * 0.45, y: h * 0.56)
            DoodleSticker(.plant, scale: 0.8).position(x: w * 0.8, y: h * 0.53)
            DoodleSticker(.tea, scale: 0.8).position(x: w * 0.2, y: h * 0.92)
            DoodleSticker(.flames, scale: 0.8).position(x: w * 0.53, y: h * 0.93)
            DoodleSticker(.sundae, scale: 0.8).position(x: w * 0.84, y: h * 0.9)
        }
    }

    private func signInWithApple() {
        guard busy == nil else { return }
        busy = .apple
        Task {
            defer { busy = nil }
            do {
                let result: AppleSignIn.Result
                if LaunchArguments.isUITesting || BackendRoot.config == nil {
                    // The mock does not verify tokens, and the Apple sheet cannot be
                    // driven by the walker: skip straight to the exchange.
                    result = AppleSignIn.Result(identityToken: "mock", nonce: "mock", fullName: nil)
                } else {
                    result = try await apple.signIn()
                }
                let session = try await state.backend.auth.signInWithApple(
                    identityToken: result.identityToken, nonce: result.nonce, fullName: result.fullName)
                MockSessionStore.save(.solo)
                Haptics.success()
                await state.didSignIn(session)
            } catch is ASAuthorizationError {
                // Cancelled. Nothing to say.
            } catch {
                state.show(.error(String(localized: "couldn't sign in. try again.")))
            }
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
                state.show(.error(String(localized: "couldn't sign in. try again.")))
            }
        }
    }
}
