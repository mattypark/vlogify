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
        #expect(BackendConfig(supabaseURL: "", anonKey: "k", mediaBaseURL: "https://m") == nil)
        #expect(BackendConfig(supabaseURL: "$(SUPABASE_URL)", anonKey: "k", mediaBaseURL: "https://m") == nil)
        #expect(BackendConfig(supabaseURL: "http://evil.example", anonKey: "k", mediaBaseURL: "https://m") == nil)
        #expect(BackendConfig(supabaseURL: "https://x.supabase.co", anonKey: "", mediaBaseURL: "https://m") == nil)
        let config = BackendConfig(supabaseURL: " https://x.supabase.co ", anonKey: "anon", mediaBaseURL: "https://media.vlogify.app")
        #expect(config?.supabaseURL.host == "x.supabase.co")
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
