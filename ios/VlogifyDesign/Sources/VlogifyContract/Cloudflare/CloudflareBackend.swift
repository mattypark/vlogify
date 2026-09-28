import Foundation
import VlogifyEngine

/// The real backend: the Cloudflare Worker in `worker/`, over `URLSession` and nothing else.
///
/// One object satisfies all eight protocols, as `MockBackend` does, so the composition root
/// swaps one value. Every `/v1` request carries the session token from `TokenStore`; the
/// Worker answers refusals as `{ "error": "<code>" }`, and those codes map one-to-one onto
/// `ContractError`. Anything the app cannot act on -- no connection, a 5xx, a body it cannot
/// decode -- is `.network`, which the UI already treats as "try again".
///
/// Clips live on the phones. The Worker relays them between friends and keeps a copy in R2
/// for seven days; `downloadURL` returns a short-lived URL the Worker signed itself.
public final class CloudflareBackend: Sendable {
    public let config: BackendConfig
    let tokens: any TokenStore
    let urlSession: URLSession
    let timeZone: TimeZone
    let now: @Sendable () -> Date
    /// How often `PresenceService` asks for the room's day. v1 has no socket.
    let pollInterval: Duration

    public init(config: BackendConfig,
                tokens: any TokenStore,
                urlSession: URLSession = .shared,
                timeZone: TimeZone = .current,
                now: @escaping @Sendable () -> Date = { Date() },
                pollInterval: Duration = .seconds(30)) {
        self.config = config
        self.tokens = tokens
        self.urlSession = urlSession
        self.timeZone = timeZone
        self.now = now
        self.pollInterval = pollInterval
    }

    /// The app-facing bundle: the same object behind every protocol.
    public var backend: Backend {
        Backend(auth: self, profile: self, rooms: self, clips: self, media: self,
                presence: self, safety: self, push: self)
    }

    // MARK: Requests

    enum Method: String {
        case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE"
    }

    /// Unreserved characters only, so an id holding "/" (the camera builds clip ids from
    /// the slot key) stays one path segment.
    static let segmentAllowed = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func encode(_ component: String) -> String {
        component.addingPercentEncoding(withAllowedCharacters: segmentAllowed) ?? component
    }

    /// `segments` are joined under the base URL, each percent-encoded on its own.
    func url(_ segments: [String], query: [String: String] = [:]) -> URL {
        var components = URLComponents(url: config.apiBaseURL, resolvingAgainstBaseURL: false)
            ?? URLComponents()
        var base = components.percentEncodedPath
        while base.hasSuffix("/") { base.removeLast() }
        components.percentEncodedPath = base + "/" + segments.map(Self.encode).joined(separator: "/")
        components.percentEncodedQuery = query.isEmpty ? nil : query
            .sorted { $0.key < $1.key }
            .map { "\(Self.encode($0.key))=\(Self.encode($0.value))" }
            .joined(separator: "&")
        return components.url ?? config.apiBaseURL
    }

    /// Sends one request and returns the body of a 2xx. Maps every failure onto
    /// `ContractError`; a 401 on an authorized request also forgets the dead session so
    /// `session` reads nil and the app shows sign-in.
    @discardableResult
    func send(_ method: Method, _ segments: [String], query: [String: String] = [:],
              body: Data? = nil, authorized: Bool = true) async throws -> Data {
        var request = URLRequest(url: url(segments, query: query))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authorized {
            guard let token = tokens.load()?.token else { throw ContractError.notSignedIn }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw ContractError.network
        }
        try check(response, data: data, authorized: authorized)
        return data
    }

    func check(_ response: URLResponse, data: Data, authorized: Bool) throws {
        guard let http = response as? HTTPURLResponse else { throw ContractError.network }
        guard !(200..<300).contains(http.statusCode) else { return }
        let code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
        let error = Self.contractError(code: code, status: http.statusCode)
        if error == .notSignedIn, authorized { tokens.clear() }
        throw error
    }

    struct ErrorBody: Decodable {
        let error: String
    }

    /// The Worker's error codes (worker/src/errors.ts) onto the contract's cases.
    static func contractError(code: String?, status: Int) -> ContractError {
        switch code {
        case "not_signed_in", "banned": return .notSignedIn
        case "not_member": return .notMember
        case "not_owner": return .notOwner
        case "room_not_found": return .roomNotFound
        case "invalid_code": return .invalidCode
        case "room_full": return .roomFull
        case "slot_already_posted": return .slotAlreadyPosted
        case "clip_too_long": return .clipTooLong
        case "rate_limited": return .rateLimited
        case "unsupported": return .unsupported
        default: return status == 401 ? .notSignedIn : .network
        }
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder.contract.decode(type, from: data)
        } catch {
            throw ContractError.network
        }
    }

    func json(_ value: some Encodable) throws -> Data {
        do {
            return try JSONEncoder.contract.encode(value)
        } catch {
            throw ContractError.network
        }
    }

    func get<T: Decodable>(_ type: T.Type, _ segments: [String], query: [String: String] = [:]) async throws -> T {
        try decode(type, from: try await send(.get, segments, query: query))
    }
}

// MARK: - Bodies the contract has no type for

struct AppleSignInBody: Encodable {
    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case nonce
        case authorizationCode = "authorization_code"
        case fullName = "full_name"
    }

    let identityToken: String
    let nonce: String
    let authorizationCode: String?
    let fullName: String?
}

struct SignInResponse: Decodable {
    let token: String
    let session: Session
}

struct ClipEnvelope: Encodable {
    let clip: Clip
}

struct PreviewResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case room
        case memberCount = "member_count"
    }

    let room: Room
    let memberCount: Int
}

struct InviteResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case inviteCode = "invite_code"
    }

    let inviteCode: InviteCode
}

struct SignedDownload: Decodable {
    enum CodingKeys: String, CodingKey {
        case url
        case expiresAt = "expires_at"
    }

    let url: URL
    let expiresAt: Date
}
