import Foundation
import Testing
import VlogifyEngine
@testable import VlogifyContract

struct WireTests {
    @Test("Clips encode with snake_case keys and ISO dates, and decode back")
    func clipRoundTrip() throws {
        let clip = Clip(id: "c", roomID: "r", memberID: "m", day: DayKey(year: 2026, month: 9, day: 11), hour: 17,
                        durationMs: 2_000, width: 1080, height: 1920, storageKey: "r/2026-09-11/17-m.mov",
                        createdAt: Date(timeIntervalSince1970: 1_789_000_000))
        let data = try JSONEncoder.contract.encode(clip)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"room_id\":\"r\""))
        #expect(json.contains("\"duration_ms\":2000"))
        #expect(json.contains("\"created_at\":\"2026-"))
        #expect(try JSONDecoder.contract.decode(Clip.self, from: data) == clip)
    }

    @Test("Backend config is nil for empty, unsubstituted, or http values")
    func config() {
        #expect(BackendConfig(apiBaseURL: "") == nil)
        #expect(BackendConfig(apiBaseURL: nil) == nil)
        #expect(BackendConfig(apiBaseURL: "$(VLOGIFY_API_URL)") == nil)
        #expect(BackendConfig(apiBaseURL: "http://evil.example") == nil)
        let config = BackendConfig(apiBaseURL: " https://vlogify.example.workers.dev ")
        #expect(config?.apiBaseURL.host == "vlogify.example.workers.dev")
    }

    @Test("Profiles carry the mark, and an unreadable mark decodes as none")
    func profileMark() throws {
        let profile = Profile(id: "u", displayName: "sam", avatarSeed: 3,
                              createdAt: Date(timeIntervalSince1970: 1_789_000_000), mark: .sample(1))
        let data = try JSONEncoder.contract.encode(profile)
        #expect(try JSONDecoder.contract.decode(Profile.self, from: data) == profile)

        let broken = #"{"id":"u","display_name":"sam","avatar_seed":3,"mark":"!!","created_at":"2026-09-10T00:00:00Z"}"#
        let decoded = try JSONDecoder.contract.decode(Profile.self, from: Data(broken.utf8))
        #expect(decoded.mark == nil)
        #expect(decoded.displayName == "sam")

        let missing = #"{"id":"u","display_name":"sam","avatar_seed":3,"created_at":"2026-09-10T00:00:00Z"}"#
        #expect(try JSONDecoder.contract.decode(Profile.self, from: Data(missing.utf8)).mark == nil)
    }

    @Test("A day log exposes posted slots in order")
    func dayLog() {
        let day = DayKey(year: 2026, month: 9, day: 11)
        func clip(_ hour: Int, _ member: String) -> Clip {
            Clip(id: "\(hour)-\(member)", roomID: "r", memberID: member, day: day, hour: hour, durationMs: 2_000,
                 width: 1, height: 1, storageKey: "", createdAt: Date())
        }
        let log = DayLog(roomID: "r", day: day, members: [], clips: [clip(9, "a"), clip(4, "b"), clip(9, "b")])
        #expect(log.postedSlots.map(\.hour) == [4, 9])
        #expect(log.clips(in: Slot(day: day, hour: 9)).count == 2)
        #expect(log.clip(from: "b", in: Slot(day: day, hour: 4))?.id == "4-b")
    }
}
