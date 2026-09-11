import Foundation
import Observation
import VlogifyContract
import VlogifyEngine

/// Everything the screens share. One object, injected once, no view models.
@MainActor
@Observable
final class AppState {
    enum Tab: String { case camera, logs }

    enum Gate: Equatable {
        case welcome, language, permissions, profile, home
    }

    let backend: Backend
    let clock: Clock
    let permissions: Permissions
    let scheduler: HourlyScheduler
    let cache: LocalMediaCache
    let capture = CapturePreferences()

    var session: Session?
    var profile: Profile?
    var rooms: [Room] = []
    var roomProgress: [RoomID: DayLog] = [:]
    var tab: Tab = .logs
    var toast: Toast?
    var pendingJoinCode: InviteCode?
    var isLoading = false
    /// The chosen language, or nil on a first launch. Drives the environment locale.
    var language: AppLanguage? = AppLanguage.current
    var languageChosen = AppLanguage.current != nil

    /// Set once the permissions screen has been walked through. Persisted, because
    /// the screen is a one-time introduction, not a gate on every launch -- a denied
    /// permission is handled where it is needed, with a link to Settings.
    var permissionsIntroDone: Bool {
        didSet { UserDefaults.standard.set(permissionsIntroDone, forKey: "permissionsIntroDone") }
    }

    init(backend: Backend, clock: Clock, permissions: Permissions,
         scheduler: HourlyScheduler, cache: LocalMediaCache) {
        self.backend = backend
        self.clock = clock
        self.permissions = permissions
        self.scheduler = scheduler
        self.cache = cache
        self.permissionsIntroDone = UserDefaults.standard.bool(forKey: "permissionsIntroDone")
        if let forced = LaunchArguments.permissions { permissionsIntroDone = forced != "unasked" }
    }

    var gate: Gate {
        guard session != nil else { return .welcome }
        // Asked once, right after sign-in: the welcome page has to work in every
        // language at once anyway, and a person who has not signed in has nothing
        // else to set up yet.
        guard languageChosen else { return .language }
        guard permissionsIntroDone else { return .permissions }
        guard let profile, !profile.displayName.isEmpty else { return .profile }
        return .home
    }

    var isSignedIn: Bool { session != nil }

    func setLanguage(_ language: AppLanguage) {
        AppLanguage.current = language
        self.language = language
        // Pings are worded in the app language; re-plan so tonight's say the same.
        scheduler.replan(rooms: rooms, clock: clock)
    }

    // MARK: Session

    func restoreSession() async {
        session = await backend.auth.session
        if session != nil {
            profile = try? await backend.profile.me()
            await loadRooms()
        }
    }

    func didSignIn(_ session: Session) async {
        self.session = session
        profile = try? await backend.profile.me()
        await loadRooms()
    }

    func signOut() async {
        await backend.auth.signOut()
        scheduler.cancelAll()
        session = nil
        profile = nil
        rooms = []
        roomProgress = [:]
    }

    func deleteAccount() async throws {
        try await backend.auth.deleteAccount()
        scheduler.cancelAll()
        cache.wipe()
        session = nil
        profile = nil
        rooms = []
        roomProgress = [:]
        permissionsIntroDone = false
    }

    func saveDisplayName(_ name: String) async throws {
        profile = try await backend.profile.update(displayName: name)
    }

    // MARK: Rooms

    func loadRooms() async {
        guard isSignedIn else { return }
        do {
            rooms = try await backend.rooms.rooms()
            let today = clock.today
            for room in rooms {
                roomProgress[room.id] = try? await backend.clips.day(roomID: room.id, day: today)
            }
            scheduler.replan(rooms: rooms, clock: clock)
        } catch {
            show(.error(String(localized: "couldn't load your rooms.", bundle: .app)))
        }
    }

    func createRoom(_ draft: RoomDraft) async throws -> Room {
        let room = try await backend.rooms.create(draft)
        await loadRooms()
        return room
    }

    func joinRoom(code: InviteCode) async throws -> Room {
        let room = try await backend.rooms.join(code: code)
        await loadRooms()
        return room
    }

    func leaveRoom(_ room: Room) async {
        try? await backend.rooms.leave(roomID: room.id)
        await loadRooms()
    }

    /// Whether the current member has already posted into the current slot of a room.
    func hasPosted(in room: Room, slot: Slot) -> Bool {
        guard let session, let log = roomProgress[room.id] else { return false }
        return log.clip(from: session.userID, in: slot) != nil
    }

    /// Rooms that can take a clip right now.
    var capturableRooms: [Room] {
        rooms.filter { room in
            room.type == .vlog || !hasPosted(in: room, slot: clock.currentSlot)
        }
    }

    // MARK: Toasts

    func show(_ toast: Toast) {
        self.toast = toast
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if self.toast == toast { self.toast = nil }
        }
    }

    /// `vlogify://join/<code>` from a shared link.
    func handle(url: URL) {
        guard url.scheme == "vlogify", url.host == "join",
              let code = InviteCode(url.lastPathComponent) else { return }
        pendingJoinCode = code
    }
}

struct Toast: Equatable {
    enum Kind { case info, error, success }
    let kind: Kind
    let text: String

    static func info(_ text: String) -> Toast { Toast(kind: .info, text: text) }
    static func error(_ text: String) -> Toast { Toast(kind: .error, text: text) }
    static func success(_ text: String) -> Toast { Toast(kind: .success, text: text) }
}
