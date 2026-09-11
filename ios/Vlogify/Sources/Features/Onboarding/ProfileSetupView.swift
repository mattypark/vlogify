import SwiftUI
import VlogifyContract
import VlogifyDesign

/// A name. That is the whole profile.
struct ProfileSetupView: View {
    @Environment(AppState.self) private var state
    @State private var name = ""
    @State private var busy = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("what do friends call you?")
                .font(.vlogTitle)
                .foregroundStyle(Color.chalk)
            Text("this is the name on your tiles.")
                .font(.vlogBody)
                .foregroundStyle(Color.chalkSoft)
            HStack(spacing: Space.sm) {
                AvatarDisc(profile: preview, size: 44)
                TextField("your name", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.vlogBody)
                    .foregroundStyle(Color.chalk)
                    .focused($focused)
                    .onChange(of: name) { _, new in name = String(new.prefix(20)) }
                    .accessibilityIdentifier("profile.name")
            }
            .padding(Space.md)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
            Spacer()
            PillButton(title: "let's go", style: .accent, isLoading: busy) { save() }
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.5 : 1)
                .accessibilityIdentifier("profile.save")
        }
        .padding(Space.gutter)
        .padding(.top, Space.xxl)
        .background(Color.ink.ignoresSafeArea())
        .onAppear {
            name = state.profile?.displayName ?? ""
            focused = true
        }
        .accessibilityIdentifier("screen.profile")
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private var preview: Profile {
        Profile(id: state.profile?.id ?? "me", displayName: trimmed.isEmpty ? "?" : trimmed,
                avatarSeed: state.profile?.avatarSeed ?? 7, createdAt: Date())
    }

    private func save() {
        busy = true
        Task {
            defer { busy = false }
            do {
                try await state.saveDisplayName(trimmed)
                Haptics.success()
            } catch {
                state.show(.error(String(localized: "couldn't save that. try again.")))
            }
        }
    }
}
