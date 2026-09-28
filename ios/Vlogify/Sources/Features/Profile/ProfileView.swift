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
    @State private var redrawing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Space.sm) {
                        if let profile = state.profile { AvatarDisc(profile: profile, size: 44) }
                        TextField("your name", text: $name)
                            .textInputAutocapitalization(.never)
                            .font(.vlogBody).foregroundStyle(Color.text)
                            .onSubmit { save() }
                            .accessibilityIdentifier("profile.nameField")
                    }
                } header: { Text("you").font(.vlogCaption) }
                .listRowBackground(Color.card)

                Section {
                    Button { showLanguage = true } label: {
                        row("language", value: state.language?.nativeName ?? "")
                    }
                    .accessibilityIdentifier("settings.language")
                    Button {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        row("hourly nudges", value: state.permissions.notifications == .granted ? String(localized: "on", bundle: .app) : String(localized: "off", bundle: .app))
                    }
                    .accessibilityIdentifier("settings.pings")
                    Button { state.capture.shuffleFont() } label: {
                        HStack {
                            Text("time font").font(.vlogBody).foregroundStyle(Color.text)
                            Spacer()
                            Text(verbatim: "5:00").font(state.capture.stampFont.font(size: 18)).foregroundStyle(Color.text)
                        }
                    }
                    .accessibilityIdentifier("settings.font")
                    Button { redrawing = true } label: {
                        HStack {
                            Text("your mark").font(.vlogBody).foregroundStyle(Color.text)
                            Spacer()
                            MarkView(mark: state.profile?.mark, name: state.profile?.displayName ?? "", size: 30)
                            Text("redraw").font(.vlogCaption).foregroundStyle(Color.textSoft)
                        }
                    }
                    .accessibilityIdentifier("settings.mark")
                    Button { state.capture.toggle() } label: {
                        row("recording", value: state.capture.isLandscape ? String(localized: "horizontal", bundle: .app) : String(localized: "vertical", bundle: .app))
                    }
                    .accessibilityIdentifier("settings.orientation")
                    Button { showBlocked = true } label: { row("blocked people", value: "") }
                        .accessibilityIdentifier("settings.blocked")
                    row("clips on this phone", value: ByteCountFormatter.string(fromByteCount: state.cache.sizeOnDisk, countStyle: .file))
                } header: { Text("settings").font(.vlogCaption) }
                .listRowBackground(Color.card)

                Section {
                    Link(destination: Legal.privacy) { row("privacy policy", value: "") }
                        .accessibilityIdentifier("legal.privacy")
                    Link(destination: Legal.terms) { row("terms", value: "") }
                        .accessibilityIdentifier("legal.terms")
                    Link(destination: Legal.support) { row("help & support", value: "") }
                        .accessibilityIdentifier("legal.support")
                    row("version", value: Legal.version)
                } header: { Text("about").font(.vlogCaption) }
                .listRowBackground(Color.card)

                Section {
                    Button("sign out") { confirmSignOut = true }
                        .foregroundStyle(Color.text)
                        .accessibilityIdentifier("account.signOut")
                    Button("delete account", role: .destructive) { confirmDelete = true }
                        .accessibilityIdentifier("account.delete")
                } header: { Text("account").font(.vlogCaption) } footer: {
                    Text("deleting removes your account, your clips, and the rooms you own. it cannot be undone.")
                }
                .listRowBackground(Color.card)
            }
            .scrollContentBackground(.hidden)
            .background(Color.ground.ignoresSafeArea())
            .navigationTitle("profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("done") { save(); dismiss() }.font(.vlogLabel).foregroundStyle(Color.text) } }
        }
        .tint(Color.text)
        .presentationBackground(Color.ground)
        .onAppear { name = state.profile?.displayName ?? "" }
        .sheet(isPresented: $showBlocked) { BlockedUsersView() }
        .sheet(isPresented: $redrawing) { RedrawMarkSheet() }
        .sheet(isPresented: $showLanguage) { LanguageView(isChanging: true).presentationBackground(Color.ground) }
        .confirmationDialog("sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("sign out", role: .destructive) { Task { await state.signOut(); MockSessionStore.save(nil); dismiss() } }
        }
        .confirmationDialog("delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("delete everything", role: .destructive) { deleteAccount() }
                .accessibilityIdentifier("account.deleteConfirm")
        } message: {
            Text("your clips, your rooms, and your sign-in are removed from vlogify's servers. friends keep their own clips. to also stop using Sign in with Apple for vlogify, open Settings > your name > Sign in with Apple.")
        }
        .screen("screen.profile")
    }

    private func row(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title).font(.vlogBody).foregroundStyle(Color.text)
            Spacer()
            Text(verbatim: value).font(.vlogCaption).foregroundStyle(Color.textSoft)
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
    static let privacy = URL(string: "https://vlogify.matthew-parkk0.workers.dev/privacy")!
    static let terms = URL(string: "https://vlogify.matthew-parkk0.workers.dev/terms")!
    static let support = URL(string: "https://vlogify.matthew-parkk0.workers.dev/support")!
    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}

/// Redraw your mark from Profile. Saving replaces it everywhere: your avatar, your
/// clips' badges, and on your friends' phones the next time they refresh.
struct RedrawMarkSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var strokes: [[CGPoint]] = []
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                DoodleRound(doodle: .cross, label: "close") { dismiss() }
                Spacer()
            }
            Text("draw a new mark.")
                .font(.vlogTitle)
                .foregroundStyle(Color.text)
            MarkEditor(strokes: $strokes)
            Spacer(minLength: Space.xs)
            PillButton(title: "save it", style: .filled, isLoading: busy) { save() }
                .disabled(strokes.isEmpty)
                .opacity(strokes.isEmpty ? 0.4 : 1)
                .accessibilityIdentifier("mark.save")
        }
        .padding(Space.gutter)
        .background(Color.ground.ignoresSafeArea())
        .presentationBackground(Color.ground)
        .screen("screen.redrawMark")
    }

    private func save() {
        busy = true
        Task {
            defer { busy = false }
            do {
                try await state.saveMark(Mark(canvas: strokes))
                await state.loadRooms()
                Haptics.success()
                dismiss()
            } catch {
                state.show(.error(String(localized: "couldn't save that. try again.", bundle: .app)))
            }
        }
    }
}
