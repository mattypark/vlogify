import Foundation
import VlogifyEngine

// The shapes that cross the wire. Every one is a plain value, `Codable`, and
// `Sendable`, with its JSON keys spelled out in snake_case by hand: Foundation's
// key-conversion strategy turns `roomID` into `room_id` on the way out and `roomId`
// on the way back, and that asymmetry is a decoding crash in production. The backend
// session maps these names to columns; it does not rename them. Add a field with a
// default rather than changing one -- old builds keep decoding.

public typealias UserID = String
public typealias RoomID = String
public typealias ClipID = String

public struct Profile: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarSeed = "avatar_seed"
        case mark
        case createdAt = "created_at"
    }

    public let id: UserID
    public var displayName: String
    /// A hue index, 0...11. Older builds drew it as the person's colour; it stays on the
    /// wire so those builds keep drawing the same colour, and nothing remaps it.
    public var avatarSeed: Int
    /// The doodle the person drew. Nil until they draw one, which onboarding asks for.
    public var mark: Mark?
    public var createdAt: Date

    public init(id: UserID, displayName: String, avatarSeed: Int, createdAt: Date, mark: Mark? = nil) {
        self.id = id
        self.displayName = displayName
        self.avatarSeed = avatarSeed
        self.createdAt = createdAt
        self.mark = mark
    }

    /// A mark the app cannot read is treated as no mark (the person is asked to draw
    /// again) rather than failing the whole profile -- a room with one unreadable
    /// member must still open.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UserID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        avatarSeed = try container.decode(Int.self, forKey: .avatarSeed)
        mark = try? container.decodeIfPresent(Mark.self, forKey: .mark)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

public struct Room: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case capacity
        case ownerID = "owner_id"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
    }

    public let id: RoomID
    public var name: String?
    public var type: RoomType
    public var capacity: Int
    public var ownerID: UserID
    public var inviteCode: InviteCode
    public var createdAt: Date

    public init(id: RoomID, name: String?, type: RoomType, capacity: Int,
                ownerID: UserID, inviteCode: InviteCode, createdAt: Date) {
        self.id = id
        self.name = name
        self.type = type
        self.capacity = capacity
        self.ownerID = ownerID
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }

    public var isSolo: Bool { type == .vlog }
}

/// What the new-room sheet produces.
public struct RoomDraft: Codable, Hashable, Sendable {
    public var name: String?
    public var type: RoomType
    public var capacity: Int

    public init(name: String?, type: RoomType, capacity: Int) {
        self.name = name
        self.type = type
        self.capacity = capacity
    }
}

public struct Membership: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case userID = "user_id"
        case profile
        case joinedAt = "joined_at"
    }

    public var id: String { "\(roomID)/\(userID)" }
    public let roomID: RoomID
    public let userID: UserID
    public var profile: Profile
    public var joinedAt: Date

    public init(roomID: RoomID, userID: UserID, profile: Profile, joinedAt: Date) {
        self.roomID = roomID
        self.userID = userID
        self.profile = profile
        self.joinedAt = joinedAt
    }
}

public struct Clip: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case memberID = "member_id"
        case day
        case hour
        case durationMs = "duration_ms"
        case width
        case height
        case storageKey = "storage_key"
        case createdAt = "created_at"
    }

    public let id: ClipID
    public let roomID: RoomID
    public let memberID: UserID
    public let day: DayKey
    public let hour: Int
    public var durationMs: Int
    public var width: Int
    public var height: Int
    /// Object key in the media store. Never a URL: URLs are minted per request.
    public var storageKey: String
    public var createdAt: Date

    public init(id: ClipID, roomID: RoomID, memberID: UserID, day: DayKey, hour: Int,
                durationMs: Int, width: Int, height: Int, storageKey: String, createdAt: Date) {
        self.id = id
        self.roomID = roomID
        self.memberID = memberID
        self.day = day
        self.hour = hour
        self.durationMs = durationMs
        self.width = width
        self.height = height
        self.storageKey = storageKey
        self.createdAt = createdAt
    }

    public var slot: Slot { Slot(day: day, hour: hour) }
}

/// A room's day: the members and every clip posted into it.
public struct DayLog: Codable, Hashable, Sendable {
    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case day
        case members
        case clips
    }

    public let roomID: RoomID
    public let day: DayKey
    public var members: [Membership]
    public var clips: [Clip]

    public init(roomID: RoomID, day: DayKey, members: [Membership], clips: [Clip]) {
        self.roomID = roomID
        self.day = day
        self.members = members
        self.clips = clips
    }

    public func clips(in slot: Slot) -> [Clip] {
        clips.filter { $0.slot == slot }
    }

    public func clip(from memberID: UserID, in slot: Slot) -> Clip? {
        clips.first { $0.memberID == memberID && $0.slot == slot }
    }

    /// Slots with at least one clip, in order. What the export stitches.
    public var postedSlots: [Slot] {
        Array(Set(clips.map(\.slot))).sorted()
    }
}

/// Where and how to upload one clip. The backend mints these; the app PUTs to `url`
/// with `headers` and then calls `ClipService.post` with the metadata.
public struct SignedUpload: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case url
        case headers
        case storageKey = "storage_key"
        case expiresAt = "expires_at"
    }

    public let url: URL
    public let headers: [String: String]
    public let storageKey: String
    public let expiresAt: Date

    public init(url: URL, headers: [String: String], storageKey: String, expiresAt: Date) {
        self.url = url
        self.headers = headers
        self.storageKey = storageKey
        self.expiresAt = expiresAt
    }
}

/// Reserved for the end-to-end path. A v1 backend never sees this type; a v2 backend
/// stores the ciphertext and the wrapped room key and can play nothing.
public struct EncryptedBlob: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case ciphertext
        case nonce
        case wrappedKeyID = "wrapped_key_id"
    }

    public let ciphertext: Data
    public let nonce: Data
    public let wrappedKeyID: String

    public init(ciphertext: Data, nonce: Data, wrappedKeyID: String) {
        self.ciphertext = ciphertext
        self.nonce = nonce
        self.wrappedKeyID = wrappedKeyID
    }
}

public enum RoomEvent: Sendable, Equatable {
    case clipPosted(Clip)
    case memberJoined(Membership)
    case memberLeft(UserID)
}

public enum ReportReason: String, Codable, CaseIterable, Sendable {
    case harassment, nudity, violence, spam, impersonation, other
}

public struct Report: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case reporterID = "reporter_id"
        case clipID = "clip_id"
        case userID = "user_id"
        case reason
        case note
        case createdAt = "created_at"
    }

    public let reporterID: UserID
    public let clipID: ClipID?
    public let userID: UserID?
    public let reason: ReportReason
    public let note: String?
    public let createdAt: Date

    public init(reporterID: UserID, clipID: ClipID?, userID: UserID?,
                reason: ReportReason, note: String?, createdAt: Date) {
        self.reporterID = reporterID
        self.clipID = clipID
        self.userID = userID
        self.reason = reason
        self.note = note
        self.createdAt = createdAt
    }
}

public struct Session: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case provider
        case issuedAt = "issued_at"
    }

    public let userID: UserID
    public let provider: AuthProviderKind
    public let issuedAt: Date

    public init(userID: UserID, provider: AuthProviderKind, issuedAt: Date) {
        self.userID = userID
        self.provider = provider
        self.issuedAt = issuedAt
    }
}

public enum AuthProviderKind: String, Codable, Sendable {
    case apple, google, email
}

public enum ContractError: Error, Equatable, Sendable {
    case notSignedIn
    case roomFull
    case roomNotFound
    case invalidCode
    case slotAlreadyPosted
    case clipTooLong
    case notOwner
    case notMember
    case invalidEmailCode
    /// Too many attempts (invite codes); try again later.
    case rateLimited
    /// The backend does not offer this (Google and email sign-in until there is a
    /// sending domain).
    case unsupported
    case network
}

public extension JSONEncoder {
    /// The one encoder the contract uses. ISO-8601 dates, sorted keys so two encodes
    /// of the same value are byte-identical. No key strategy: keys are explicit.
    static var contract: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var contract: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
