import AuthenticationServices
import SwiftUI
import VlogifyContract
import VlogifyDesign

/// The first thing anyone sees: three pages, one drawing each, a few plain lines, and
/// one drawn button. The drawing traces itself when its page arrives. The last page is
/// where you sign in.
///
/// Sign in with Apple is the way in. Google and email appear only while the app runs on
/// the on-device mock (the walker uses them); the real backend offers Apple alone until
/// there is a domain to send email codes from.
struct WelcomeView: View {
    @Environment(AppState.self) private var state
    @State private var page = 0
    @State private var showEmail = false
    @State private var busy: AuthProviderKind?
    private let apple = AppleSignIn()
    private let google = GoogleSignIn()

    private struct Page {
        let doodle: Doodle
        let lines: LocalizedStringKey
        let next: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(doodle: .clock,
             lines: "most of a day never gets filmed.\nthe walk, the lunch, the 11 pm kitchen.\nthose were the good parts.",
             next: "okay"),
        Page(doodle: .phoneBuzz,
             lines: "once an hour, everyone in your room\ngets the same nudge.\ntwo seconds. one take. no redo.",
             next: "and then?"),
        Page(doodle: .frames,
             lines: "at night it all lines up\ninto one vlog, side by side.\nyours to keep.",
             next: ""),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Wordmark(size: 28)
                Spacer()
                dots
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.md)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index], index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.lg)
        }
        .background(Color.ground.ignoresSafeArea())
        .sheet(isPresented: $showEmail) { EmailSignInSheet() }
        .toastOverlay(state.toast)
        .screen("screen.welcome")
        .onAppear { if let step = LaunchArguments.step { page = min(max(step, 0), pages.count - 1) } }
    }

    private func pageView(_ page: Page, index: Int) -> some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            Spacer()
            HStack {
                Spacer()
                // Re-created when its page arrives, so it draws itself each time.
                if self.page == index {
                    DoodleSticker(page.doodle, scale: 1.15, animated: true, lineWidth: Pen.bold)
                } else {
                    Color.clear.frame(width: page.doodle.size.width * 1.15, height: page.doodle.size.height * 1.15)
                }
                Spacer()
            }
            Text(page.lines)
                .font(.vlogBody.weight(.medium))
                .lineSpacing(5)
                .foregroundStyle(Color.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, Space.xl)
    }

    private var dots: some View {
        HStack(spacing: Space.xs) {
            ForEach(pages.indices, id: \.self) { index in
                Group {
                    if index == page {
                        Circle().fill(Color.text)
                    } else {
                        PenShape(.circle, wobble: 0.4).stroke(Color.text, style: Ink.style(1.2))
                    }
                }
                .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("page \(page + 1) of \(pages.count)"))
    }

    @ViewBuilder
    private var footer: some View {
        if page < pages.count - 1 {
            HStack {
                Spacer()
                Button {
                    Haptics.tap()
                    withAnimation(Motion.shift) { page += 1 }
                } label: {
                    Text(pages[page].next)
                        .font(.vlogShout)
                        .foregroundStyle(Color.text)
                        .padding(.horizontal, Space.xl)
                        .frame(height: 56)
                        .frame(minWidth: 150)
                }
                .buttonStyle(StickerButtonStyle(fill: .card, corner: .capsule))
                .accessibilityIdentifier("welcome.next")
                Spacer()
            }
            .frame(height: 150, alignment: .top)
        } else {
            signIn
                .frame(height: 150, alignment: .top)
        }
    }

    private var signIn: some View {
        VStack(spacing: Space.sm) {
            // Apple's own button, unaltered (4.8 and the HIG both want it recognisable).
            SignInWithAppleButton(.continue) { _ in } onCompletion: { _ in }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(Capsule())
                .overlay(Capsule().fill(Color.black.opacity(0.001)).onTapGesture { signInWithApple() })
                .overlay { if busy == .apple { ProgressView().tint(.white) } }
                .accessibilityIdentifier("welcome.apple")
            legal
            if BackendRoot.usesMock {
                // Only on the mock: the walker needs every door, and "skip" walks the
                // whole onboarding with no account at all.
                HStack(spacing: Space.lg) {
                    Button("google") { signInWithGoogle() }
                        .accessibilityIdentifier("welcome.google")
                    Button("email") { showEmail = true }
                        .accessibilityIdentifier("welcome.email")
                    Button("skip for now") { skip() }
                        .accessibilityIdentifier("welcome.skip")
                }
                .font(.vlogHandSmall)
                .foregroundStyle(Color.textSoft)
                .buttonStyle(.plain)
            }
        }
    }

    private var legal: some View {
        Text("by continuing you agree to the [terms](\(Legal.terms.absoluteString)) and [privacy policy](\(Legal.privacy.absoluteString)).")
            .font(.vlogCaption)
            .foregroundStyle(Color.textSoft)
            .tint(Color.text)
            .multilineTextAlignment(.center)
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
