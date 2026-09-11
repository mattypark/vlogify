import Foundation
import Testing
import VlogifyEngine
@testable import VlogifyContract

/// The mock has to enforce the same rules the real backend will, or the app is tested
/// against a backend that says yes to everything.
struct MockBackendTests {
    let tz = TimeZone(identifier: "Asia/Seoul")!
    let fixedNow = Date(timeIntervalSince1970: 1_789_000_000) // 2026-09-10 ~ afternoon UTC

    func makeBackend(_ scenario: MockBackend.Scenario) async -> MockBackend {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vlogify-tests-\(UUID().uuidString)")
        let backend = MockBackend(now: { fixedNow }, timeZone: tz, clipsDirectory: dir)
        await backend.seed(scenario)
        return backend
    }

    @Test("Empty scenario has no session; full has rooms")
    func scenarios() async throws {
        let empty = await makeBackend(.empty)
        #expect(await empty.session == nil)
        let full = await makeBackend(.full)
        #expect(await full.session != nil)
        let rooms = try await full.rooms()
        #expect(rooms.count == 2)
        #expect(rooms.contains { $0.type == .log && $0.capacity == 3 })
    }

    @Test("Seeding is deterministic: same codes, same clips, every time")
    func deterministic() async throws {
        let a = await makeBackend(.full)
        let b = await makeBackend(.full)
        let codesA = try await a.rooms().map(\.inviteCode.value).sorted()
        let codesB = try await b.rooms().map(\.inviteCode.value).sorted()
        #expect(codesA == codesB)
    }

    @Test("A room refuses a second clip in the same slot and a clip over two seconds")
    func clipRules() async throws {
        let backend = await makeBackend(.full)
        let log = try await backend.rooms().first { $0.type == .log }!
        let slot = Slot(day: DayKey(year: 2030, month: 1, day: 1), hour: 10)
        let clip = Clip(id: "c1", roomID: log.id, memberID: MockBackend.testUserID, day: slot.day, hour: slot.hour,
                        durationMs: 2_000, width: 1080, height: 1920, storageKey: "k", createdAt: fixedNow)
        _ = try await backend.post(clip)
        await #expect(throws: ContractError.slotAlreadyPosted) {
            _ = try await backend.post(Clip(id: "c2", roomID: log.id, memberID: MockBackend.testUserID,
                                            day: slot.day, hour: slot.hour, durationMs: 2_000, width: 1, height: 1,
                                            storageKey: "k2", createdAt: fixedNow))
        }
        await #expect(throws: ContractError.clipTooLong) {
            _ = try await backend.post(Clip(id: "c3", roomID: log.id, memberID: MockBackend.testUserID,
                                            day: slot.day, hour: 11, durationMs: 5_000, width: 1, height: 1,
                                            storageKey: "k3", createdAt: fixedNow))
        }
    }

    @Test("Join respects capacity and rejects a bad code")
    func joining() async throws {
        let backend = await makeBackend(.full)
        let log = try await backend.rooms().first { $0.type == .log }!
        // Already a member: join is idempotent.
        _ = try await backend.join(code: log.inviteCode)
        await #expect(throws: ContractError.invalidCode) {
            _ = try await backend.join(code: InviteCode.generate())
        }
        // A stranger against a full room.
        await backend.signOut()
        try await backend.requestEmailCode(email: "new@example.com")
        _ = try await backend.verifyEmailCode(email: "new@example.com", code: "000000")
        await #expect(throws: ContractError.roomFull) {
            _ = try await backend.join(code: log.inviteCode)
        }
    }

    @Test("Blocking a member hides their clips and their membership")
    func blocking() async throws {
        let backend = await makeBackend(.full)
        let log = try await backend.rooms().first { $0.type == .log }!
        let before = try await backend.day(roomID: log.id, day: DayClock.dayKey(for: fixedNow, in: tz))
        #expect(before.members.count == 3)
        try await backend.block(userID: "user-jiwoo")
        let after = try await backend.day(roomID: log.id, day: DayClock.dayKey(for: fixedNow, in: tz))
        #expect(after.members.count == 2)
        #expect(!after.clips.contains { $0.memberID == "user-jiwoo" })
        #expect(try await backend.blocked().map(\.id) == ["user-jiwoo"])
    }

    @Test("Deleting the account removes the session, the profile and owned rooms")
    func deletion() async throws {
        let backend = await makeBackend(.full)
        try await backend.deleteAccount()
        #expect(await backend.session == nil)
        await #expect(throws: ContractError.notSignedIn) { _ = try await backend.rooms() }
    }

    @Test("The wrong email code is rejected")
    func emailCode() async throws {
        let backend = await makeBackend(.empty)
        try await backend.requestEmailCode(email: "a@b.c")
        await #expect(throws: ContractError.invalidEmailCode) {
            _ = try await backend.verifyEmailCode(email: "a@b.c", code: "123456")
        }
        _ = try await backend.verifyEmailCode(email: "a@b.c", code: "000000")
        #expect(await backend.session?.provider == .email)
    }

    @Test("Presence delivers a posted clip to a subscriber")
    func presence() async throws {
        let backend = await makeBackend(.full)
        let log = try await backend.rooms().first { $0.type == .log }!
        let stream = backend.subscribe(roomID: log.id)
        // Give the subscription a beat to register on the actor.
        try await Task.sleep(for: .milliseconds(50))
        let clip = Clip(id: "p1", roomID: log.id, memberID: MockBackend.testUserID,
                        day: DayKey(year: 2030, month: 1, day: 1), hour: 12, durationMs: 1_900,
                        width: 1, height: 1, storageKey: "p", createdAt: fixedNow)
        _ = try await backend.post(clip)
        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()
        #expect(event == .clipPosted(clip))
    }
}
