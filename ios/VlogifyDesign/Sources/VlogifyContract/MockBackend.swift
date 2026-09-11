import Foundation
import VlogifyEngine

/// The whole backend, on one phone.
///
/// Every protocol in `Services.swift`, satisfied by an actor holding dictionaries and
/// a folder of real clip files. This is what the app ships against until a
/// `Secrets.xcconfig` exists, what previews run on, and what the overnight walker
/// drives -- so it has to behave like the real thing (room full is an error, a second
/// clip in a slot is an error, a code with a bad checksum is an error), not like a
/// stub that says yes.
///
/// Seeding is deterministic: `seed(.full)` produces the same rooms, members, codes and
/// clips every launch, so a screenshot taken tonight matches one taken tomorrow.
public actor MockBackend {
    public enum Scenario: String, Sendable {
        /// First launch. No session, no rooms.
        case empty
        /// Signed in, a three-person log with clips through the current hour, a solo
        /// vlog, and two past days of history.
        case full
        /// Signed in, one solo vlog only.
        case solo
    }

    let now: @Sendable () -> Date
    let timeZone: TimeZone
    let clipsDirectory: URL
    let sampleClip: URL?

    var activeSession: Session?
    var profiles: [UserID: Profile] = [:]
    var rooms: [RoomID: Room] = [:]
    var memberships: [RoomID: [Membership]] = [:]
    var clips: [ClipID: Clip] = [:]
    var blocked: Set<UserID> = []
    var reports: [Report] = []
    var pendingEmailCodes: [String: String] = [:]
    var listeners: [RoomID: [AsyncStream<RoomEvent>.Continuation]] = [:]
    var generator = SeededGenerator(seed: 0x5e7_106)

    /// - Parameters:
    ///   - clipsDirectory: where uploaded clip files are written. Use a temp directory
    ///     in tests.
    ///   - sampleClip: a bundled .mov the seeded clips point at, so the compositor and
    ///     the player have real frames to show in the simulator, which has no camera.
    public init(now: @escaping @Sendable () -> Date = { Date() },
                timeZone: TimeZone = .current,
                clipsDirectory: URL,
                sampleClip: URL? = nil) {
        self.now = now
        self.timeZone = timeZone
        self.clipsDirectory = clipsDirectory
        self.sampleClip = sampleClip
        try? FileManager.default.createDirectory(at: clipsDirectory, withIntermediateDirectories: true)
    }

    // MARK: Seeding

    public static let testUserID = "user-me"
    /// Signing in with this address and code `000000` lands on the seeded account.
    /// It is what the App Review notes hand to the reviewer.
    public static let testEmail = "review@vlogify.app"
    public static let testCode = "000000"

    public func seed(_ scenario: Scenario) {
        activeSession = nil
        profiles = [:]
        rooms = [:]
        memberships = [:]
        clips = [:]
        generator = SeededGenerator(seed: 0x5e7_106)
        guard scenario != .empty else { return }

        let created = now().addingTimeInterval(-86_400 * 12)
        let me = Profile(id: Self.testUserID, displayName: "matthew", avatarSeed: 7, createdAt: created)
        let jiwoo = Profile(id: "user-jiwoo", displayName: "jiwoo", avatarSeed: 2, createdAt: created)
        let sam = Profile(id: "user-sam", displayName: "sam", avatarSeed: 11, createdAt: created)
        for profile in [me, jiwoo, sam] { profiles[profile.id] = profile }
        activeSession = Session(userID: me.id, provider: .apple, issuedAt: created)

        let solo = makeRoom(RoomDraft(name: "just me", type: .vlog, capacity: 1), owner: me.id, createdAt: created)
        addMember(me, to: solo.id, at: created)

        guard scenario == .full else { return }

        let trio = makeRoom(RoomDraft(name: "lololol testing", type: .log, capacity: 3), owner: me.id, createdAt: created)
        for profile in [me, jiwoo, sam] { addMember(profile, to: trio.id, at: created) }

        // Clips through the current hour today, and two full-ish past days. Members
        // miss hours on purpose -- an empty tile is a state the UI has to show well.
        let today = DayClock.slot(for: now(), in: timeZone)
        let days = [today.day, previousDay(today.day, by: 1), previousDay(today.day, by: 2)]
        for (dayIndex, day) in days.enumerated() {
            for slot in DayClock.slots(of: day) {
                if dayIndex == 0, slot.hour > today.hour { break }
                if slot.hour > 25 { continue }
                for (memberIndex, profile) in [me, jiwoo, sam].enumerated() {
                    // Everyone posts most hours; each member skips a different one.
                    if (slot.hour + memberIndex) % 7 == 0 { continue }
                    seedClip(room: trio.id, member: profile.id, slot: slot)
                }
                if dayIndex == 0 || slot.hour % 3 == 0 {
                    seedClip(room: solo.id, member: me.id, slot: slot)
                }
            }
        }
    }

    func previousDay(_ day: DayKey, by count: Int) -> DayKey {
        let start = DayClock.date(of: day, hour: DayClock.resetHour, minute: 0, in: timeZone)
        let earlier = start.addingTimeInterval(-86_400 * Double(count) + 3_600)
        return DayClock.dayKey(for: earlier, in: timeZone)
    }

    func seedClip(room roomID: RoomID, member: UserID, slot: Slot) {
        let id = "clip-\(roomID)-\(member)-\(slot.key)"
        let storageKey = sampleClip?.lastPathComponent ?? "\(id).mov"
        clips[id] = Clip(id: id, roomID: roomID, memberID: member, day: slot.day, hour: slot.hour,
                         durationMs: 2_000, width: 1080, height: 1920, storageKey: storageKey,
                         createdAt: SlotPing.fireDate(room: roomID, slot: slot, in: timeZone).addingTimeInterval(90))
    }

    func makeRoom(_ draft: RoomDraft, owner: UserID, createdAt: Date) -> Room {
        let room = Room(id: "room-\(rooms.count + 1)", name: draft.name, type: draft.type,
                        capacity: draft.capacity, ownerID: owner,
                        inviteCode: InviteCode.generate(using: &generator), createdAt: createdAt)
        rooms[room.id] = room
        return room
    }

    func addMember(_ profile: Profile, to roomID: RoomID, at date: Date) {
        let membership = Membership(roomID: roomID, userID: profile.id, profile: profile, joinedAt: date)
        memberships[roomID, default: []].append(membership)
    }

    func requireSession() throws -> Session {
        guard let session = activeSession else { throw ContractError.notSignedIn }
        return session
    }

    func requireMember(_ userID: UserID, of roomID: RoomID) throws {
        guard memberships[roomID]?.contains(where: { $0.userID == userID }) == true else {
            throw ContractError.notMember
        }
    }

    func emit(_ event: RoomEvent, in roomID: RoomID) {
        listeners[roomID]?.forEach { $0.yield(event) }
    }

    func signIn(as userID: UserID, name: String, provider: AuthProviderKind) -> Session {
        if profiles[userID] == nil {
            profiles[userID] = Profile(id: userID, displayName: name, avatarSeed: Int(generator.next() % 12), createdAt: now())
        }
        let session = Session(userID: userID, provider: provider, issuedAt: now())
        activeSession = session
        return session
    }

    /// Exposed for tests and the debug menu.
    public var currentSession: Session? { activeSession }
}

// MARK: - AuthService

extension MockBackend: AuthService {
    public var session: Session? {
        get async { currentSession }
    }

    public func signInWithApple(identityToken: String, nonce: String, fullName: String?) async throws -> Session {
        signIn(as: Self.testUserID, name: fullName ?? "you", provider: .apple)
    }

    public func beginGoogleSignIn() async throws -> URL {
        URL(string: "vlogify://auth/google?mock=1")!
    }

    public func completeGoogleSignIn(callback: URL) async throws -> Session {
        signIn(as: Self.testUserID, name: "you", provider: .google)
    }

    public func requestEmailCode(email: String) async throws {
        // The one code, so the walker and the review notes can both use it.
        pendingEmailCodes[email.lowercased()] = Self.testCode
    }

    public func verifyEmailCode(email: String, code: String) async throws -> Session {
        let address = email.lowercased()
        guard pendingEmailCodes[address] == code else { throw ContractError.invalidEmailCode }
        // A distinct account per address, so a second email is a second person --
        // that is how the tests exercise "room full" without a second device.
        let userID = address == Self.testEmail ? Self.testUserID : "user-\(address)"
        return signIn(as: userID, name: String(address.split(separator: "@").first ?? "you"), provider: .email)
    }

    public func signOut() async {
        activeSession = nil
    }

    public func deleteAccount() async throws {
        let session = try requireSession()
        for (id, clip) in clips where clip.memberID == session.userID { clips[id] = nil }
        for roomID in memberships.keys {
            memberships[roomID]?.removeAll { $0.userID == session.userID }
        }
        rooms = rooms.filter { $0.value.ownerID != session.userID }
        profiles[session.userID] = nil
        activeSession = nil
    }
}

// MARK: - ProfileService

extension MockBackend: ProfileService {
    public func me() async throws -> Profile {
        let session = try requireSession()
        guard let profile = profiles[session.userID] else { throw ContractError.notSignedIn }
        return profile
    }

    public func update(displayName: String) async throws -> Profile {
        let session = try requireSession()
        guard var profile = profiles[session.userID] else { throw ContractError.notSignedIn }
        profile.displayName = displayName
        profiles[session.userID] = profile
        for roomID in memberships.keys {
            memberships[roomID] = memberships[roomID]?.map { membership in
                guard membership.userID == session.userID else { return membership }
                var updated = membership
                updated.profile = profile
                return updated
            }
        }
        return profile
    }
}

// MARK: - RoomService

extension MockBackend: RoomService {
    public func rooms() async throws -> [Room] {
        let session = try requireSession()
        return rooms.values
            .filter { memberships[$0.id]?.contains { $0.userID == session.userID } == true }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func room(id: RoomID) async throws -> Room {
        let session = try requireSession()
        try requireMember(session.userID, of: id)
        guard let room = rooms[id] else { throw ContractError.roomNotFound }
        return room
    }

    public func create(_ draft: RoomDraft) async throws -> Room {
        let session = try requireSession()
        guard RoomRules.isValidCapacity(draft.capacity, for: draft.type) else { throw ContractError.roomFull }
        guard let profile = profiles[session.userID] else { throw ContractError.notSignedIn }
        let room = makeRoom(draft, owner: session.userID, createdAt: now())
        addMember(profile, to: room.id, at: now())
        return room
    }

    public func preview(code: InviteCode) async throws -> (room: Room, memberCount: Int) {
        _ = try requireSession()
        guard let room = rooms.values.first(where: { $0.inviteCode == code }) else {
            throw ContractError.invalidCode
        }
        return (room, memberships[room.id]?.count ?? 0)
    }

    public func join(code: InviteCode) async throws -> Room {
        let session = try requireSession()
        let (room, count) = try await preview(code: code)
        if memberships[room.id]?.contains(where: { $0.userID == session.userID }) == true { return room }
        guard RoomRules.canJoin(memberCount: count, capacity: room.capacity) else { throw ContractError.roomFull }
        guard let profile = profiles[session.userID] else { throw ContractError.notSignedIn }
        addMember(profile, to: room.id, at: now())
        if let membership = memberships[room.id]?.last { emit(.memberJoined(membership), in: room.id) }
        return room
    }

    public func leave(roomID: RoomID) async throws {
        let session = try requireSession()
        try requireMember(session.userID, of: roomID)
        memberships[roomID]?.removeAll { $0.userID == session.userID }
        emit(.memberLeft(session.userID), in: roomID)
    }

    public func members(roomID: RoomID) async throws -> [Membership] {
        let session = try requireSession()
        try requireMember(session.userID, of: roomID)
        return (memberships[roomID] ?? []).filter { !blocked.contains($0.userID) }
    }

    public func removeMember(userID: UserID, from roomID: RoomID) async throws {
        let session = try requireSession()
        guard rooms[roomID]?.ownerID == session.userID else { throw ContractError.notOwner }
        memberships[roomID]?.removeAll { $0.userID == userID }
        emit(.memberLeft(userID), in: roomID)
    }

    public func regenerateInvite(roomID: RoomID) async throws -> InviteCode {
        let session = try requireSession()
        guard var room = rooms[roomID], room.ownerID == session.userID else { throw ContractError.notOwner }
        room.inviteCode = InviteCode.generate(using: &generator)
        rooms[roomID] = room
        return room.inviteCode
    }
}

// MARK: - ClipService

extension MockBackend: ClipService {
    public func post(_ clip: Clip) async throws -> Clip {
        let session = try requireSession()
        try requireMember(session.userID, of: clip.roomID)
        guard let room = rooms[clip.roomID] else { throw ContractError.roomNotFound }
        if let limit = RoomRules.clipLimit(for: room.type), Double(clip.durationMs) > limit * 1_000 + 250 {
            throw ContractError.clipTooLong
        }
        if let cap = RoomRules.capturesPerSlot(for: room.type) {
            let posted = clips.values.filter { $0.roomID == clip.roomID && $0.memberID == session.userID && $0.slot == clip.slot }
            guard posted.count < cap else { throw ContractError.slotAlreadyPosted }
        }
        clips[clip.id] = clip
        emit(.clipPosted(clip), in: clip.roomID)
        return clip
    }

    public func day(roomID: RoomID, day: DayKey) async throws -> DayLog {
        let session = try requireSession()
        try requireMember(session.userID, of: roomID)
        let members = (memberships[roomID] ?? []).filter { !blocked.contains($0.userID) }
        let dayClips = clips.values
            .filter { $0.roomID == roomID && $0.day == day && !blocked.contains($0.memberID) }
            .sorted { ($0.hour, $0.createdAt) < ($1.hour, $1.createdAt) }
        return DayLog(roomID: roomID, day: day, members: members, clips: dayClips)
    }

    public func history(roomID: RoomID) async throws -> [DayKey] {
        let session = try requireSession()
        try requireMember(session.userID, of: roomID)
        return Array(Set(clips.values.filter { $0.roomID == roomID }.map(\.day))).sorted(by: >)
    }

    public func delete(clipID: ClipID) async throws {
        let session = try requireSession()
        guard let clip = clips[clipID], clip.memberID == session.userID else { throw ContractError.notOwner }
        clips[clipID] = nil
    }
}

// MARK: - MediaStore

extension MockBackend: MediaStore {
    public func uploadURL(for clip: Clip) async throws -> SignedUpload {
        let key = "\(clip.roomID)/\(clip.day)/\(clip.hour)-\(clip.memberID).mov"
        return SignedUpload(url: clipsDirectory.appendingPathComponent(key), headers: [:],
                            storageKey: key, expiresAt: now().addingTimeInterval(600))
    }

    public func upload(fileURL: URL, to signed: SignedUpload) async throws {
        let destination = signed.url
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: fileURL, to: destination)
    }

    public func downloadURL(storageKey: String) async throws -> URL {
        let local = clipsDirectory.appendingPathComponent(storageKey)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        if let sampleClip, sampleClip.lastPathComponent == storageKey { return sampleClip }
        if let sampleClip { return sampleClip }
        throw ContractError.network
    }
}

// MARK: - PresenceService

extension MockBackend: PresenceService {
    nonisolated public func subscribe(roomID: RoomID) -> AsyncStream<RoomEvent> {
        AsyncStream { continuation in
            Task { await self.register(continuation, for: roomID) }
        }
    }

    func register(_ continuation: AsyncStream<RoomEvent>.Continuation, for roomID: RoomID) {
        listeners[roomID, default: []].append(continuation)
    }
}

// MARK: - SafetyService

extension MockBackend: SafetyService {
    public func report(_ report: Report) async throws {
        _ = try requireSession()
        reports.append(report)
    }

    public func block(userID: UserID) async throws {
        _ = try requireSession()
        blocked.insert(userID)
    }

    public func unblock(userID: UserID) async throws {
        _ = try requireSession()
        blocked.remove(userID)
    }

    public func blocked() async throws -> [Profile] {
        _ = try requireSession()
        return blocked.compactMap { profiles[$0] }.sorted { $0.displayName < $1.displayName }
    }

    /// For tests.
    public var reportCount: Int { reports.count }
}

// MARK: - PushService

extension MockBackend: PushService {
    public func register(deviceToken: Data) async throws {}
    public func unregister() async throws {}
}

public extension MockBackend {
    /// The app-facing bundle. Nonisolated: it only captures `self`, which is the
    /// whole point -- the same actor behind every protocol.
    nonisolated var backend: Backend {
        Backend(auth: self, profile: self, rooms: self, clips: self, media: self,
                presence: self, safety: self, push: self)
    }
}

/// SplitMix64. Deterministic so seeded data is identical across launches.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }
}
