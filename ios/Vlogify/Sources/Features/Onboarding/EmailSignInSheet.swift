import SwiftUI
import VlogifyContract
import VlogifyDesign

/// Address, then a six-digit code. No passwords anywhere in the app.
struct EmailSignInSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var sent = false
    @State private var busy = false
    @State private var problem: String?
    @FocusState private var focus: Field?

    enum Field { case email, code }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.md) {
                Text(sent ? "check your email" : "your email")
                    .font(.vlogTitle)
                    .foregroundStyle(Color.text)
                if sent {
                    Text("we sent a 6-digit code to \(email).")
                        .font(.vlogBody)
                        .foregroundStyle(Color.textSoft)
                    TextField("000000", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(Font.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.text)
                        .focused($focus, equals: .code)
                        .onChange(of: code) { _, new in code = String(new.filter(\.isNumber).prefix(6)) }
                        .accessibilityIdentifier("email.code")
                } else {
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.vlogBody)
                        .foregroundStyle(Color.text)
                        .padding(Space.md)
                        .background(Color.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                        .focused($focus, equals: .email)
                        .accessibilityIdentifier("email.address")
                }
                if let problem {
                    Text(verbatim: problem)
                        .font(.vlogCaption)
                        .foregroundStyle(Color.emberInk)
                        .accessibilityIdentifier("email.error")
                }
                Spacer()
                PillButton(title: sent ? "sign in" : "send code", style: .accent, isLoading: busy) { submit() }
                    .disabled(sent ? code.count < 6 : !isValidEmail)
                    .opacity((sent ? code.count < 6 : !isValidEmail) ? 0.5 : 1)
                    .accessibilityIdentifier("email.submit")
                if sent {
                    Button("use a different email") { sent = false; code = ""; problem = nil; focus = .email }
                        .font(.vlogCaption)
                        .foregroundStyle(Color.textSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: Metrics.hitTarget)
                }
            }
            .padding(Space.gutter)
            .background(Color.ground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }.foregroundStyle(Color.text)
                }
            }
            .onAppear { focus = .email }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.ground)
    }

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard let at = trimmed.firstIndex(of: "@"), at != trimmed.startIndex else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        return domain.contains(".") && !domain.hasSuffix(".") && !trimmed.contains(" ")
    }

    private func submit() {
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            do {
                let address = email.trimmingCharacters(in: .whitespaces).lowercased()
                if sent {
                    let session = try await state.backend.auth.verifyEmailCode(email: address, code: code)
                    MockSessionStore.save(address == MockBackend.testEmail ? .full : .solo)
                    Haptics.success()
                    dismiss()
                    await state.didSignIn(session)
                } else {
                    try await state.backend.auth.requestEmailCode(email: address)
                    sent = true
                    focus = .code
                }
            } catch ContractError.invalidEmailCode {
                problem = String(localized: "that code didn't match. check the email and try again.", bundle: .app)
                Haptics.error()
            } catch {
                problem = String(localized: "something went wrong. try again in a moment.", bundle: .app)
            }
        }
    }
}
