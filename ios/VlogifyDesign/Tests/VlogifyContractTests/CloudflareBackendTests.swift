import Foundation
import Testing
import VlogifyEngine
@testable import VlogifyContract

/// The Cloudflare client against a stubbed network: the paths, methods, bodies and headers
/// it sends, how it reads what comes back, and how the Worker's error codes land on
/// `ContractError`. The Worker's own tests (worker/test) pin the other half.
struct CloudflareBackendTests {
    // MARK: Fixtures

    static let stamp = "2026-09-28T10:00:00Z"
    static let profileJSON = #"{"id":"u1","display_name":"sam","avatar_seed":3,"created_at":"2026-09-28T10:00:00Z"}"#
    static let roomJSON = #"{"id":"r1","name":"trio","type":"log","capacity":3,"owner_id":"u1","invite_code":"REV1EF","created_at":"2026-09-28T10:00:00Z"}"#
    static let clipJSON = #"{"id":"c1","room_id":"r1","member_id":"u1","day":"2026-09-28","hour":17,"duration_ms":2000,"width":1080,"height":1920,"storage_key":"clips/r1/2026-09-28/c1.mov","created_at":"2026-09-28T10:00:00Z"}"#

    static func clip(id: String = "c1") -> Clip {
        Clip(id: id, roomID: "r1", memberID: "u1", day: DayKey(year: 2026, month: 9, day: 28), hour: 17,
             durationMs: 2_000, width: 1080, height: 1920, storageKey: "", createdAt: Date(timeIntervalSince1970: 1_790_590_000))
    }

    static let signedIn = StoredSession(token: "tok-123",
                                        session: Session(userID: "u1", provider: .apple, issuedAt: Date(timeIntervalSince1970: 1_790_000_000)))

    // MARK: Auth

    @Test("Apple sign-in posts the token, nonce, code and name, and keeps the session")
    func appleSignIn() async throws {
        let harness = Harness(tokens: InMemoryTokenStore())
        harness.respond(200, #"{"token":"tok-new","session":{"user_id":"u9","provider":"apple","issued_at":"2026-09-28T10:00:00Z"}}"#)
        let session = try await harness.backend.signInWithApple(identityToken: "id-token", nonce: "raw-nonce",
                                                                authorizationCode: "code-1", fullName: "Sam")
        #expect(session.userID == "u9")
        #expect(await harness.backend.session == session)
        #expect(harness.tokens.load()?.token == "tok-new")

        let request = try #require(harness.requests.first)
        #expect(request.method == "POST")
        #expect(request.path == "/v1/auth/apple")
        #expect(request.authorization == nil)
        let body = try #require(request.jsonBody)
        #expect(body["identity_token"] as? String == "id-token")
        #expect(body["nonce"] as? String == "raw-nonce")
        #expect(body["authorization_code"] as? String == "code-1")
        #expect(body["full_name"] as? String == "Sam")
    }

    @Test("Google and email sign-in are unsupported without asking the network")
    func unsupportedProviders() async {
        let harness = Harness()
        await #expect(throws: ContractError.unsupported) { try await harness.backend.beginGoogleSignIn() }
        await #expect(throws: ContractError.unsupported) { try await harness.backend.requestEmailCode(email: "a@b.co") }
        await #expect(throws: ContractError.unsupported) { try await harness.backend.verifyEmailCode(email: "a@b.co", code: "000000") }
        #expect(harness.requests.isEmpty)
    }

    @Test("Every /v1 call carries the bearer token; with none it fails before the network")
    func bearer() async throws {
        let harness = Harness()
        harness.respond(200, "[\(Self.roomJSON)]")
        let rooms = try await harness.backend.rooms()
        #expect(rooms.first?.inviteCode.value == "REV1EF")
        #expect(harness.requests.first?.authorization == "Bearer tok-123")

        harness.tokens.clear()
        await #expect(throws: ContractError.notSignedIn) { try await harness.backend.rooms() }
        #expect(harness.requests.count == 1)
    }

    @Test("A 401 forgets the dead session; sign-out and delete forget it too")
    func sessionLifecycle() async throws {
        let expired = Harness()
        expired.respond(401, #"{"error":"not_signed_in"}"#)
        await #expect(throws: ContractError.notSignedIn) { try await expired.backend.me() }
        #expect(await expired.backend.session == nil)

        let leaving = Harness()
        leaving.respond(204, "")
        try await leaving.backend.deleteAccount()
        #expect(leaving.requests.first?.method == "DELETE")
        #expect(leaving.requests.first?.path == "/v1/account")
        #expect(await leaving.backend.session == nil)

        let signingOut = Harness()
        await signingOut.backend.signOut()
        #expect(signingOut.tokens.load() == nil)
    }

    // MARK: Errors

    @Test("Worker error codes map onto ContractError; anything else is .network", arguments: [
        (409, "room_full", ContractError.roomFull), (409, "slot_already_posted", .slotAlreadyPosted),
        (422, "clip_too_long", .clipTooLong), (404, "invalid_code", .invalidCode), (403, "not_member", .notMember),
        (403, "not_owner", .notOwner), (404, "room_not_found", .roomNotFound), (429, "rate_limited", .rateLimited),
        (501, "unsupported", .unsupported), (400, "bad_request", .network), (500, "server_error", .network),
        (410, "gone", .network), (502, "", .network),
    ])
    func errorMapping(status: Int, code: String, expected: ContractError) async {
        let harness = Harness()
        harness.respond(status, code.isEmpty ? "<html>bad gateway</html>" : #"{"error":"\#(code)"}"#)
        await #expect(throws: expected) { try await harness.backend.join(code: InviteCode("REV1EF")!) }
    }

    @Test("A dropped connection and an unreadable body are both .network")
    func transportFailures() async {
        let offline = Harness()
        offline.fail()
        await #expect(throws: ContractError.network) { try await offline.backend.me() }

        let garbled = Harness()
        garbled.respond(200, #"{"id":"u1"}"#)
        await #expect(throws: ContractError.network) { try await garbled.backend.me() }
    }

    // MARK: Profile and rooms

    @Test("Profile updates PATCH one field each; the mark goes as its wire string")
    func profileUpdates() async throws {
        let harness = Harness()
        harness.respond(200, Self.profileJSON)
        _ = try await harness.backend.update(displayName: "sam")
        _ = try await harness.backend.update(avatarSeed: 4)
        _ = try await harness.backend.update(mark: .sample(1))
        #expect(harness.requests.map(\.method) == ["PATCH", "PATCH", "PATCH"])
        #expect(harness.requests.allSatisfy { $0.path == "/v1/me" })
        #expect(harness.requests[0].jsonBody?["display_name"] as? String == "sam")
        #expect(harness.requests[1].jsonBody?["avatar_seed"] as? Int == 4)
        #expect(harness.requests[2].jsonBody?["mark"] as? String == Mark.sample(1).encoded)
    }

    @Test("Room calls hit the documented paths with the documented bodies")
    func roomPaths() async throws {
        let harness = Harness()
        let code = try #require(InviteCode("REV1EF"))

        harness.respond(201, Self.roomJSON)
        let created = try await harness.backend.create(RoomDraft(name: "trio", type: .log, capacity: 3))
        #expect(created.id == "r1")
        harness.respond(200, #"{"room":\#(Self.roomJSON),"member_count":2}"#)
        let preview = try await harness.backend.preview(code: code)
        #expect(preview.memberCount == 2)
        harness.respond(200, Self.roomJSON)
        _ = try await harness.backend.join(code: code)
        harness.respond(200, #"{"invite_code":"V10G5P"}"#)
        #expect(try await harness.backend.regenerateInvite(roomID: "r1").value == "V10G5P")
        harness.respond(200, #"[{"room_id":"r1","user_id":"u1","profile":\#(Self.profileJSON),"joined_at":"2026-09-28T10:00:00Z"}]"#)
        #expect(try await harness.backend.members(roomID: "r1").first?.profile.displayName == "sam")
        harness.respond(204, "")
        try await harness.backend.leave(roomID: "r1")
        try await harness.backend.removeMember(userID: "u2", from: "r1")

        let calls = harness.requests.map { "\($0.method) \($0.path)" }
        #expect(calls == [
            "POST /v1/rooms", "GET /v1/rooms/preview/REV1EF", "POST /v1/rooms/join", "POST /v1/rooms/r1/invite",
            "GET /v1/rooms/r1/members", "POST /v1/rooms/r1/leave", "DELETE /v1/rooms/r1/members/u2",
        ])
        #expect(harness.requests[0].jsonBody?["capacity"] as? Int == 3)
        #expect(harness.requests[0].jsonBody?["type"] as? String == "log")
        #expect(harness.requests[2].jsonBody?["code"] as? String == "REV1EF")
    }

    // MARK: Clips and media

    @Test("Posting wraps the clip; the day log and history decode")
    func clips() async throws {
        let harness = Harness()
        harness.respond(201, Self.clipJSON)
        let posted = try await harness.backend.post(Self.clip())
        #expect(posted.storageKey == "clips/r1/2026-09-28/c1.mov")
        let wrapped = try #require(harness.requests.last?.jsonBody?["clip"] as? [String: Any])
        #expect(wrapped["room_id"] as? String == "r1")
        #expect(wrapped["day"] as? String == "2026-09-28")

        harness.respond(200, #"{"room_id":"r1","day":"2026-09-28","members":[],"clips":[\#(Self.clipJSON)]}"#)
        let log = try await harness.backend.day(roomID: "r1", day: DayKey(year: 2026, month: 9, day: 28))
        #expect(log.clips.count == 1)
        #expect(harness.requests.last?.path == "/v1/rooms/r1/days/2026-09-28")

        harness.respond(200, #"["2026-09-28","2026-09-27"]"#)
        #expect(try await harness.backend.history(roomID: "r1") == [DayKey(year: 2026, month: 9, day: 28), DayKey(year: 2026, month: 9, day: 27)])
    }

    @Test("A clip id holding a slash stays one path segment")
    func slashInClipID() async throws {
        let harness = Harness()
        harness.respond(204, "")
        try await harness.backend.delete(clipID: "r1-u1-2026-09-28/17-1790590000")
        #expect(harness.requests.first?.rawPath == "/v1/clips/r1-u1-2026-09-28%2F17-1790590000")
    }

    @Test("Upload URL, the signed PUT, and a playback URL")
    func media() async throws {
        let harness = Harness()
        let uploadURL = "https://\(harness.host)/media/upload/c1?exp=1&sig=ab"
        harness.respond(200, #"{"url":"\#(uploadURL)","headers":{"Content-Type":"video/quicktime"},"storage_key":"clips/r1/2026-09-28/c1.mov","expires_at":"2026-09-28T10:10:00Z"}"#)
        let signed = try await harness.backend.uploadURL(for: Self.clip())
        #expect(signed.storageKey == "clips/r1/2026-09-28/c1.mov")
        #expect(harness.requests.last?.path == "/v1/clips/upload-url")

        let file = FileManager.default.temporaryDirectory.appendingPathComponent("vlogify-upload-\(UUID().uuidString).mov")
        try Data([0, 1, 2, 3]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        harness.respond(204, "")
        try await harness.backend.upload(fileURL: file, to: signed)
        let put = try #require(harness.requests.last)
        #expect(put.method == "PUT")
        #expect(put.path == "/media/upload/c1")
        #expect(put.headers["Content-Type"] == "video/quicktime")
        #expect(put.authorization == nil)

        harness.respond(403, #"{"error":"bad_signature"}"#)
        await #expect(throws: ContractError.network) { try await harness.backend.upload(fileURL: file, to: signed) }

        harness.respond(200, #"{"url":"https://\#(harness.host)/media/clips/r1/2026-09-28/c1.mov?exp=1&sig=cd","expires_at":"2026-09-28T11:00:00Z"}"#)
        let playable = try await harness.backend.downloadURL(storageKey: "clips/r1/2026-09-28/c1.mov")
        #expect(playable.path == "/media/clips/r1/2026-09-28/c1.mov")
        let sign = try #require(harness.requests.last)
        #expect(sign.path == "/v1/media/sign")
        #expect(sign.query == "key=clips%2Fr1%2F2026-09-28%2Fc1.mov")
    }

    // MARK: Safety and push

    @Test("Report, block, unblock and the blocked list")
    func safety() async throws {
        let harness = Harness()
        harness.respond(204, "")
        try await harness.backend.report(Report(reporterID: "u1", clipID: "c1", userID: nil, reason: .spam,
                                                note: "no", createdAt: Date(timeIntervalSince1970: 1_790_000_000)))
        try await harness.backend.block(userID: "u2")
        try await harness.backend.unblock(userID: "u2")
        harness.respond(200, "[\(Self.profileJSON)]")
        #expect(try await harness.backend.blocked().map(\.id) == ["u1"])
        #expect(harness.requests.map { "\($0.method) \($0.path)" } == [
            "POST /v1/reports", "POST /v1/blocks", "DELETE /v1/blocks/u2", "GET /v1/blocks",
        ])
        #expect(harness.requests[0].jsonBody?["reason"] as? String == "spam")
        #expect(harness.requests[0].jsonBody?["clip_id"] as? String == "c1")
        #expect(harness.requests[1].jsonBody?["user_id"] as? String == "u2")
    }

    @Test("Push is a no-op in v1")
    func push() async throws {
        let harness = Harness()
        try await harness.backend.register(deviceToken: Data([1, 2, 3]))
        try await harness.backend.unregister()
        #expect(harness.requests.isEmpty)
    }

    // MARK: Presence

    @Test("Presence polls today's day log and yields what changed, not the baseline")
    func presence() async throws {
        let day = DayKey(year: 2026, month: 9, day: 28)
        let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
        // 2026-09-28 19:00 in Seoul: inside app-day 2026-09-28.
        let noonish = Date(timeIntervalSince1970: 1_790_589_600)
        let harness = Harness(timeZone: seoul, now: { noonish }, pollInterval: .milliseconds(10))
        let member = #"{"room_id":"r1","user_id":"u1","profile":\#(Self.profileJSON),"joined_at":"2026-09-28T10:00:00Z"}"#
        let newcomer = member.replacingOccurrences(of: #""user_id":"u1""#, with: #""user_id":"u2""#)
        harness.respondInOrder([
            (200, #"{"room_id":"r1","day":"2026-09-28","members":[\#(member)],"clips":[]}"#),
            (500, #"{"error":"server_error"}"#),
            (200, #"{"room_id":"r1","day":"2026-09-28","members":[\#(member),\#(newcomer)],"clips":[\#(Self.clipJSON)]}"#),
            (200, #"{"room_id":"r1","day":"2026-09-28","members":[\#(newcomer)],"clips":[\#(Self.clipJSON)]}"#),
        ])

        var events: [RoomEvent] = []
        for await event in harness.backend.subscribe(roomID: "r1") {
            events.append(event)
            if events.count == 3 { break }
        }
        guard events.count == 3, case .memberJoined(let joined) = events[0], case .clipPosted(let clip) = events[1] else {
            Issue.record("unexpected events \(events)")
            return
        }
        #expect(joined.userID == "u2")
        #expect(clip.id == "c1")
        #expect(events[2] == .memberLeft("u1"))
        #expect(harness.requests.allSatisfy { $0.path == "/v1/rooms/r1/days/\(day)" })
    }
}

// MARK: - Harness

/// One backend on its own fake host, so tests running in parallel never see each other's
/// requests or responses.
final class Harness: @unchecked Sendable {
    let host = "t-\(UUID().uuidString.lowercased()).test"
    let tokens: InMemoryTokenStore
    let backend: CloudflareBackend
    private let lock = NSLock()
    private var queue: [(Int, String)] = []
    private var fallback: (Int, String)?
    private var failing = false
    private var recorded: [RecordedRequest] = []

    init(tokens: InMemoryTokenStore = InMemoryTokenStore(CloudflareBackendTests.signedIn),
         timeZone: TimeZone = .current,
         now: @escaping @Sendable () -> Date = { Date() },
         pollInterval: Duration = .seconds(30)) {
        self.tokens = tokens
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let config = BackendConfig(apiBaseURL: "https://\(host)")!
        backend = CloudflareBackend(config: config, tokens: tokens, urlSession: URLSession(configuration: configuration),
                                    timeZone: timeZone, now: now, pollInterval: pollInterval)
        StubURLProtocol.register(self, for: host)
    }

    deinit {
        StubURLProtocol.unregister(host)
    }

    /// Every later request gets this, until the next `respond`.
    func respond(_ status: Int, _ body: String) {
        lock.withLock {
            queue = []
            fallback = (status, body)
            failing = false
        }
    }

    /// One response per request, in order; the last repeats.
    func respondInOrder(_ responses: [(Int, String)]) {
        lock.withLock {
            queue = responses
            fallback = responses.last
        }
    }

    func fail() {
        lock.withLock { failing = true }
    }

    var requests: [RecordedRequest] {
        lock.withLock { recorded }
    }

    func handle(_ request: RecordedRequest) -> (Int, String)? {
        lock.withLock {
            recorded.append(request)
            if failing { return nil }
            if !queue.isEmpty { return queue.removeFirst() }
            return fallback
        }
    }
}

struct RecordedRequest: Sendable {
    let method: String
    let path: String
    let rawPath: String
    let query: String?
    let headers: [String: String]
    let body: Data?

    var authorization: String? { headers["Authorization"] }

    var jsonBody: [String: Any]? {
        body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private struct WeakHarness {
        weak var value: Harness?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var harnesses: [String: WeakHarness] = [:]

    static func register(_ harness: Harness, for host: String) {
        lock.withLock { harnesses[host] = WeakHarness(value: harness) }
    }

    static func unregister(_ host: String) {
        _ = lock.withLock { harnesses.removeValue(forKey: host) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host,
              let harness = Self.lock.withLock({ Self.harnesses[host]?.value }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let recorded = RecordedRequest(
            method: request.httpMethod ?? "GET",
            path: url.path,
            rawPath: components?.percentEncodedPath ?? url.path,
            query: components?.percentEncodedQuery,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody ?? request.httpBodyStream.map(Self.read))
        guard let (status, body) = harness.handle(recorded) else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
