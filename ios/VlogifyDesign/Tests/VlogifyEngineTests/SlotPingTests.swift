import Foundation
import Testing
@testable import VlogifyEngine

struct SlotPingTests {
    let day = DayKey(year: 2026, month: 9, day: 11)

    @Test("The same room and slot always ping at the same minute")
    func deterministic() {
        let slot = Slot(day: day, hour: 17)
        let a = SlotPing.minute(room: "room-1", slot: slot)
        let b = SlotPing.minute(room: "room-1", slot: slot)
        #expect(a == b)
    }

    @Test("Different rooms and different hours get different minutes")
    func varies() {
        let minutes = (4..<28).map { SlotPing.minute(room: "room-1", slot: Slot(day: day, hour: $0)) }
        #expect(Set(minutes).count >= 15, "hash should spread across the hour, got \(minutes)")
        let rooms = (0..<30).map { SlotPing.minute(room: "room-\($0)", slot: Slot(day: day, hour: 17)) }
        #expect(Set(rooms).count >= 15)
    }

    @Test("The ping never lands in the last ten minutes")
    func leavesTime() {
        for hour in 4..<28 {
            #expect(SlotPing.minute(room: "abc", slot: Slot(day: day, hour: hour)) <= SlotPing.latestMinute)
        }
    }

    @Test("FNV-1a matches the reference vector, so the server can reproduce it")
    func referenceVector() {
        // Known FNV-1a 64 of "a".
        #expect(SlotPing.fnv1a("a") == 0xaf63_dc4c_8601_ec8c)
    }

    @Test("Fire date is inside the slot")
    func fireDate() {
        let tz = TimeZone(identifier: "Asia/Seoul")!
        let slot = Slot(day: day, hour: 25)
        let fire = SlotPing.fireDate(room: "room-1", slot: slot, in: tz)
        #expect(fire >= DayClock.start(of: slot, in: tz))
        #expect(fire < DayClock.end(of: slot, in: tz))
    }
}
