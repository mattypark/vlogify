import Foundation
import VlogifyEngine

// The eight protocols, one route each (worker/src/routes). Paths and bodies are the ones
// docs/CONTRACT.md tabulates; the Worker tests pin the other side.

// MARK: - AuthService

extension CloudflareBackend: AuthService {
    public var session: Session? {
        get async { tokens.load()?.session }
    }

    public func signInWithApple(identityToken: String, nonce: String, authorizationCode: String?,
                                fullName: String?) async throws -> Session {
        let body = try json(AppleSignInBody(identityToken: identityToken, nonce: nonce,
                                            authorizationCode: authorizationCode, fullName: fullName))
        let data = try await send(.post, ["v1", "auth", "apple"], body: body, authorized: false)
        let signedIn = try decode(SignInResponse.self, from: data)
        tokens.save(StoredSession(token: signedIn.token, session: signedIn.session))
        return signedIn.session
    }

    /// Google and email need a sending domain and an OAuth client; until then the Worker
    /// answers `unsupported` too, so there is no reason to ask it.
    public func beginGoogleSignIn() async throws -> URL {
        throw ContractError.unsupported
    }

    public func completeGoogleSignIn(callback: URL) async throws -> Session {
        throw ContractError.unsupported
    }

    public func requestEmailCode(email: String) async throws {
        throw ContractError.unsupported
    }

    public func verifyEmailCode(email: String, code: String) async throws -> Session {
        throw ContractError.unsupported
    }

    public func signOut() async {
        tokens.clear()
    }

    public func deleteAccount() async throws {
        try await send(.delete, ["v1", "account"])
        tokens.clear()
    }
}

// MARK: - ProfileService

extension CloudflareBackend: ProfileService {
    public func me() async throws -> Profile {
        try await get(Profile.self, ["v1", "me"])
    }

    public func update(displayName: String) async throws -> Profile {
        try await patchMe(["display_name": displayName])
    }

    public func update(avatarSeed: Int) async throws -> Profile {
        try await patchMe(["avatar_seed": avatarSeed])
    }

    public func update(mark: Mark) async throws -> Profile {
        // The mock refuses an empty mark the same way.
        guard !mark.isEmpty else { throw ContractError.unsupported }
        return try await patchMe(["mark": mark.encoded])
    }

    private func patchMe<Value: Encodable>(_ fields: [String: Value]) async throws -> Profile {
        let data = try await send(.patch, ["v1", "me"], body: try json(fields))
        return try decode(Profile.self, from: data)
    }
}

// MARK: - RoomService

extension CloudflareBackend: RoomService {
    public func rooms() async throws -> [Room] {
        try await get([Room].self, ["v1", "rooms"])
    }

    public func room(id: RoomID) async throws -> Room {
        try await get(Room.self, ["v1", "rooms", id])
    }

    public func create(_ draft: RoomDraft) async throws -> Room {
        let data = try await send(.post, ["v1", "rooms"], body: try json(draft))
        return try decode(Room.self, from: data)
    }

    public func preview(code: InviteCode) async throws -> (room: Room, memberCount: Int) {
        let preview = try await get(PreviewResponse.self, ["v1", "rooms", "preview", code.value])
        return (preview.room, preview.memberCount)
    }

    public func join(code: InviteCode) async throws -> Room {
        let data = try await send(.post, ["v1", "rooms", "join"], body: try json(["code": code.value]))
        return try decode(Room.self, from: data)
    }

    public func leave(roomID: RoomID) async throws {
        try await send(.post, ["v1", "rooms", roomID, "leave"])
    }

    public func members(roomID: RoomID) async throws -> [Membership] {
        try await get([Membership].self, ["v1", "rooms", roomID, "members"])
    }

    public func removeMember(userID: UserID, from roomID: RoomID) async throws {
        try await send(.delete, ["v1", "rooms", roomID, "members", userID])
    }

    public func regenerateInvite(roomID: RoomID) async throws -> InviteCode {
        let data = try await send(.post, ["v1", "rooms", roomID, "invite"])
        return try decode(InviteResponse.self, from: data).inviteCode
    }
}

// MARK: - ClipService

extension CloudflareBackend: ClipService {
    public func post(_ clip: Clip) async throws -> Clip {
        let data = try await send(.post, ["v1", "clips"], body: try json(ClipEnvelope(clip: clip)))
        return try decode(Clip.self, from: data)
    }

    public func day(roomID: RoomID, day: DayKey) async throws -> DayLog {
        try await get(DayLog.self, ["v1", "rooms", roomID, "days", day.description])
    }

    public func history(roomID: RoomID) async throws -> [DayKey] {
        try await get([DayKey].self, ["v1", "rooms", roomID, "history"])
    }

    public func delete(clipID: ClipID) async throws {
        try await send(.delete, ["v1", "clips", clipID])
    }
}

// MARK: - MediaStore

extension CloudflareBackend: MediaStore {
    public func uploadURL(for clip: Clip) async throws -> SignedUpload {
        let data = try await send(.post, ["v1", "clips", "upload-url"], body: try json(ClipEnvelope(clip: clip)))
        return try decode(SignedUpload.self, from: data)
    }

    /// PUTs the file to the URL the Worker signed, with the headers it asked for. The URL
    /// carries its own signature, so no bearer token goes with it.
    public func upload(fileURL: URL, to signed: SignedUpload) async throws {
        var request = URLRequest(url: signed.url)
        request.httpMethod = "PUT"
        for (name, value) in signed.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.upload(for: request, fromFile: fileURL)
        } catch {
            throw ContractError.network
        }
        try check(response, data: data, authorized: false)
    }

    public func downloadURL(storageKey: String) async throws -> URL {
        try await get(SignedDownload.self, ["v1", "media", "sign"], query: ["key": storageKey]).url
    }
}

// MARK: - SafetyService

extension CloudflareBackend: SafetyService {
    public func report(_ report: Report) async throws {
        try await send(.post, ["v1", "reports"], body: try json(report))
    }

    public func block(userID: UserID) async throws {
        try await send(.post, ["v1", "blocks"], body: try json(["user_id": userID]))
    }

    public func unblock(userID: UserID) async throws {
        try await send(.delete, ["v1", "blocks", userID])
    }

    public func blocked() async throws -> [Profile] {
        try await get([Profile].self, ["v1", "blocks"])
    }
}

// MARK: - PushService

/// v1 pings are local notifications scheduled from `SlotPing`; the server holds no device
/// tokens. Kept as no-ops so the app's calls stay where APNs will plug in.
extension CloudflareBackend: PushService {
    public func register(deviceToken: Data) async throws {}
    public func unregister() async throws {}
}
