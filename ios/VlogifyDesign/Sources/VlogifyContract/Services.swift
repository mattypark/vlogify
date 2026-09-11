import Foundation
import VlogifyEngine

// The protocols every backend satisfies. Each is small and independently mockable,
// which is what lets a view be previewed against one fake rather than a whole fake
// world. The app talks to these and only these; nothing in the app imports a vendor
// SDK.

public protocol AuthService: Sendable {
    var session: Session? { get async }
    /// `identityToken` and `nonce` come straight from `ASAuthorization`. The backend
    /// verifies the token with Apple and returns a session; the app never sees the
    /// verification.
    func signInWithApple(identityToken: String, nonce: String, fullName: String?) async throws -> Session
    /// Google goes through the system browser, not a bundled SDK: the app opens this
    /// URL in `ASWebAuthenticationSession` and hands the callback back.
    func beginGoogleSignIn() async throws -> URL
    func completeGoogleSignIn(callback: URL) async throws -> Session
    func requestEmailCode(email: String) async throws
    func verifyEmailCode(email: String, code: String) async throws -> Session
    func signOut() async
    /// Permanently deletes the account and everything it posted. App Store guideline
    /// 5.1.1(v): not optional for any app with accounts, and sign-out does not count.
    /// Must also revoke the Sign in with Apple token server-side.
    func deleteAccount() async throws
}

public protocol ProfileService: Sendable {
    func me() async throws -> Profile
    func update(displayName: String) async throws -> Profile
    /// The user's colour (avatar disc, tile outline, recording frame). 0...11.
    func update(avatarSeed: Int) async throws -> Profile
}

public protocol RoomService: Sendable {
    func rooms() async throws -> [Room]
    func room(id: RoomID) async throws -> Room
    func create(_ draft: RoomDraft) async throws -> Room
    /// Looks a code up without joining, so the join sheet can show the room first.
    func preview(code: InviteCode) async throws -> (room: Room, memberCount: Int)
    func join(code: InviteCode) async throws -> Room
    func leave(roomID: RoomID) async throws
    func members(roomID: RoomID) async throws -> [Membership]
    func removeMember(userID: UserID, from roomID: RoomID) async throws
    func regenerateInvite(roomID: RoomID) async throws -> InviteCode
}

public protocol ClipService: Sendable {
    /// Called after the bytes are in the media store. The backend enforces the 2 s
    /// cap and one-per-slot rule again; the app enforces them first.
    func post(_ clip: Clip) async throws -> Clip
    func day(roomID: RoomID, day: DayKey) async throws -> DayLog
    /// Days with at least one clip, newest first.
    func history(roomID: RoomID) async throws -> [DayKey]
    func delete(clipID: ClipID) async throws
}

public protocol MediaStore: Sendable {
    func uploadURL(for clip: Clip) async throws -> SignedUpload
    func upload(fileURL: URL, to signed: SignedUpload) async throws
    /// A playable URL. For the mock it is a file in the container; for R2 it is a
    /// short-lived presigned GET.
    func downloadURL(storageKey: String) async throws -> URL
}

public protocol PresenceService: Sendable {
    func subscribe(roomID: RoomID) -> AsyncStream<RoomEvent>
}

public protocol SafetyService: Sendable {
    func report(_ report: Report) async throws
    func block(userID: UserID) async throws
    func unblock(userID: UserID) async throws
    func blocked() async throws -> [Profile]
}

public protocol PushService: Sendable {
    func register(deviceToken: Data) async throws
    func unregister() async throws
}

/// Everything the app needs, in one place, so the composition root swaps one value.
public struct Backend: Sendable {
    public let auth: any AuthService
    public let profile: any ProfileService
    public let rooms: any RoomService
    public let clips: any ClipService
    public let media: any MediaStore
    public let presence: any PresenceService
    public let safety: any SafetyService
    public let push: any PushService

    public init(auth: any AuthService, profile: any ProfileService, rooms: any RoomService,
                clips: any ClipService, media: any MediaStore, presence: any PresenceService,
                safety: any SafetyService, push: any PushService) {
        self.auth = auth
        self.profile = profile
        self.rooms = rooms
        self.clips = clips
        self.media = media
        self.presence = presence
        self.safety = safety
        self.push = push
    }
}
