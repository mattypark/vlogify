import Testing
@testable import VlogifyEngine

struct RoomRulesTests {
    @Test("Log capacity pills are 2, 3, 4, 5 and 6-20")
    func logPills() {
        #expect(RoomRules.capacityOptions(for: .log) == [2, 3, 4, 5, 20])
        #expect(RoomRules.capacityLabel(20, for: .log) == "6-20")
        #expect(RoomRules.capacityLabel(3, for: .log) == "3")
        #expect(RoomRules.defaultCapacity(for: .log) == 3)
    }

    @Test("Capacity validation per type", arguments: [
        (RoomType.log, 1, false), (.log, 2, true), (.log, 20, true), (.log, 21, false),
        (.stack, 40, true), (.stack, 41, false), (.vlog, 1, true), (.vlog, 2, false),
        (.zip, 2, true),
    ])
    func validity(type: RoomType, capacity: Int, valid: Bool) {
        #expect(RoomRules.isValidCapacity(capacity, for: type) == valid)
    }

    @Test("Logs are two seconds and one take; vlogs are unlimited")
    func limits() {
        #expect(RoomRules.clipLimit(for: .log) == 2.0)
        #expect(RoomRules.clipLimit(for: .vlog) == nil)
        #expect(RoomRules.capturesPerSlot(for: .log) == 1)
        #expect(RoomRules.capturesPerSlot(for: .vlog) == nil)
        #expect(RoomRules.canRetake == false)
        #expect(RoomRules.pings(.log) && !RoomRules.pings(.vlog))
    }

    @Test("Names are trimmed, capped, and optional")
    func names() {
        #expect(RoomRules.normalizedName("   ") == nil)
        #expect(RoomRules.normalizedName("  lololol testing ") == "lololol testing")
        #expect(RoomRules.normalizedName(String(repeating: "a", count: 40))?.count == 24)
    }

    @Test("A room is joinable until it is at capacity")
    func joinable() {
        #expect(RoomRules.canJoin(memberCount: 2, capacity: 3))
        #expect(!RoomRules.canJoin(memberCount: 3, capacity: 3))
    }
}
