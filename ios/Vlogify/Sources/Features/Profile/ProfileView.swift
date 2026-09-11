import SwiftUI
import VlogifyContract
import VlogifyDesign

/// Name, language, pings, blocked people, the legal links, sign out, delete.
struct ProfileView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var showBlocked = false
    @State private var showLanguage = false
    @State private var confirmDelete = false
    @State private var confirmSignOut = false
    @State private var deleting = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Space.sm) {
                        if let profile = state.profile { AvatarDisc(profile: profile, size: 44) }
                        TextField("your name", text: $name)
                            .textInputAutocapitalization(.never)
                            .font(.vlogBody).foregroundStyle(Color.chalk)
                            .onSubmit { save() }
                            .accessibilityIdentifier("profile.nameField")
                    }
                } header: { Text("you") }
                .listRowBackground(Color.surface)

                Section {
                    Button { showLanguage = true } label: {
                        row("language", value: state.language?.nativeName ?? "")
                    }
                    .accessibilityIdentifier("settings.language")
                    Button {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        row("hourly pings", value: state.permissions.notifications == .granted ? String(localized: "on", bundle: .app) : String(localized: "off", bundle: .app))
                    }
                    .accessibilityIdentifier("settings.pings")
                    Button { showBlocked = true } label: { row("blocked people", value: "") }
                        .accessibilityIdentifier("settings.blocked")
                    row("clips on this phone", value: ByteCountFormatter.string(fromByteCount: state.cache.sizeOnDisk, countStyle: .file))
                } header: { Text("settings") }
                .listRowBackground(Color.surface)

                Section {
                    Link(destination: Legal.privacy) { row("privacy policy", value: "") }
                        .accessibilityIdentifier("legal.privacy")
                    Link(destination: Legal.terms) { row("terms", value: "") }
                        .accessibilityIdentifier("legal.terms")
                    Link(destination: Legal.support) { row("help & support", value: "") }
                        .accessibilityIdentifier("legal.support")
                    row("version", value: Legal.version)
                } header: { Text("about") }
                .listRowBackground(Color.surface)

                Section {
                    Button("sign out") { confirmSignOut = true }
                        .foregroundStyle(Color.chalk)
                        .accessibilityIdentifier("account.signOut")
                    Button("delete account", role: .destructive) { confirmDelete = true }
                        .accessibilityIdentifier("account.delete")
                } header: { Text("account") } footer: {
                    Text("deleting removes your account, your clips, and the rooms you own. it cannot be undone.")
                }
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("done") { save(); dismiss() }.foregroundStyle(Color.chalk) } }
        }
        .tint(Color.chalk)
        .presentationBackground(Color.ink)
        .onAppear { name = state.profile?.displayName ?? "" }
        .sheet(isPresented: $showBlocked) { BlockedUsersView() }
        .sheet(isPresented: $showLanguage) { LanguageView(isChanging: true).presentationBackground(Color.ink) }
        .confirmationDialog("sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("sign out", role: .destructive) { Task { await state.signOut(); MockSessionStore.save(nil); dismiss() } }
        }
        .confirmationDialog("delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("delete everything", role: .destructive) { deleteAccount() }
                .accessibilityIdentifier("account.deleteConfirm")
        } message: {
            Text("your clips, your rooms, and your sign-in are removed from vlogify's servers. friends keep their own clips.")
        }
        .screen("screen.profile")
    }

    private func row(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title).font(.vlogBody).foregroundStyle(Color.chalk)
            Spacer()
            Text(verbatim: value).font(.vlogCaption).foregroundStyle(Color.chalkSoft)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != state.profile?.displayName else { return }
        Task { try? await state.saveDisplayName(trimmed) }
    }

    private func deleteAccount() {
        deleting = true
        Task {
            defer { deleting = false }
            do {
                try await state.deleteAccount()
                MockSessionStore.save(nil)
                dismiss()
            } catch {
                state.show(.error(String(localized: "couldn't delete right now. try again.", bundle: .app)))
            }
        }
    }
}

/// Hosted legal pages. The App Store record links the same URLs.
enum Legal {
    static let privacy = URL(string: "https://vlogify.app/privacy")!
    static let terms = URL(string: "https://vlogify.app/terms")!
    static let support = URL(string: "https://vlogify.app/support")!
    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}
