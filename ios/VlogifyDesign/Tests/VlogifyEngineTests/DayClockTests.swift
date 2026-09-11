import Foundation
import Testing
@testable import VlogifyEngine

/// The app-day starts at 4 AM. Every grouping in the product depends on that being
/// exactly right, including across daylight-saving changes, so it is pinned here.
struct DayClockTests {
    let seoul = TimeZone(identifier: "Asia/Seoul")!
    let chicago = TimeZone(identifier: "America/Chicago")!

    func date(_ string: String, in timeZone: TimeZone) -> Date {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: string)!
    }

    @Test("3:59 AM belongs to yesterday, 4:00 AM starts today")
    func boundary() {
        let late = DayClock.slot(for: date("2026-09-11 03:59", in: seoul), in: seoul)
        #expect(late.day == DayKey(year: 2026, month: 9, day: 10))
        #expect(late.hour == 27)
        #expect(late.label == "3:00")

        let early = DayClock.slot(for: date("2026-09-11 04:00", in: seoul), in: seoul)
        #expect(early.day == DayKey(year: 2026, month: 9, day: 11))
        #expect(early.hour == 4)
        #expect(early.label == "4:00")
    }

    @Test("Midnight is hour 24 of the previous app-day")
    func midnight() {
        let slot = DayClock.slot(for: date("2026-09-12 00:30", in: seoul), in: seoul)
        #expect(slot.day == DayKey(year: 2026, month: 9, day: 11))
        #expect(slot.hour == 24)
        #expect(slot.label == "12:00")
        #expect(slot.index == 20)
    }

    @Test("A day has twenty-four slots in order")
    func slots() {
        let day = DayKey(year: 2026, month: 9, day: 11)
        let slots = DayClock.slots(of: day)
        #expect(slots.count == 24)
        #expect(slots.first?.hour == 4)
        #expect(slots.last?.hour == 27)
        #expect(slots == slots.sorted())
    }

    @Test("Slot start and end are wall-clock instants, including past midnight")
    func startEnd() {
        let slot = Slot(day: DayKey(year: 2026, month: 9, day: 11), hour: 25)
        #expect(DayClock.start(of: slot, in: seoul) == date("2026-09-12 01:00", in: seoul))
        #expect(DayClock.end(of: slot, in: seoul) == date("2026-09-12 02:00", in: seoul))
    }

    @Test("Fall-back: the 1 AM slot still starts at 1 AM on the wall, day key unchanged")
    func fallBack() {
        // Chicago falls back 2026-11-01 at 02:00 -> 01:00.
        let slot = DayClock.slot(for: date("2026-11-01 01:30", in: chicago), in: chicago)
        #expect(slot.day == DayKey(year: 2026, month: 10, day: 31))
        #expect(slot.hour == 25)
        let start = DayClock.start(of: slot, in: chicago)
        let components = DayClock.calendar(in: chicago).dateComponents([.hour, .minute], from: start)
        #expect(components.hour == 1 && components.minute == 0)
    }

    @Test("Spring-forward: the slot that does not exist resolves forward, not to a crash")
    func springForward() {
        // Chicago springs forward 2026-03-08 at 02:00 -> 03:00. Hour 26 is "2 AM".
        let slot = Slot(day: DayKey(year: 2026, month: 3, day: 7), hour: 26)
        let start = DayClock.start(of: slot, in: chicago)
        let components = DayClock.calendar(in: chicago).dateComponents([.hour], from: start)
        #expect(components.hour == 3)
    }

    @Test("Next slot rolls into the next day at 4 AM")
    func next() {
        let last = date("2026-09-12 03:10", in: seoul)
        let next = DayClock.nextSlot(after: last, in: seoul)
        #expect(next == Slot(day: DayKey(year: 2026, month: 9, day: 12), hour: 4))
    }

    @Test("Remaining slots from 5 PM are 5 PM through 3 AM")
    func remaining() {
        let remaining = DayClock.remainingSlots(from: date("2026-09-11 17:20", in: seoul), in: seoul)
        #expect(remaining.count == 11)
        #expect(remaining.first?.hour == 17)
        #expect(remaining.last?.hour == 27)
    }

    @Test("Day keys sort and print as ISO dates")
    func keys() {
        let a = DayKey(year: 2026, month: 9, day: 9)
        let b = DayKey(year: 2026, month: 10, day: 1)
        #expect(a < b)
        #expect(a.description == "2026-09-09")
    }
}
