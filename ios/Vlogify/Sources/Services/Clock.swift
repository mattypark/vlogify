import Foundation
import VlogifyEngine

/// The app's view of "now", in the user's time zone, with the debug override in one
/// place. Every screen that shows a time asks this, never `Date()` directly, so
/// `-vlogifyHour 17` really does make it five o'clock everywhere.
@MainActor
final class Clock {
    let timeZone: TimeZone
    private let overrideHour: Int?

    init(timeZone: TimeZone = .autoupdatingCurrent, overrideHour: Int? = LaunchArguments.hour) {
        self.timeZone = timeZone
        self.overrideHour = overrideHour
    }

    var now: Date {
        guard let overrideHour else { return Date() }
        let real = DayClock.slot(for: Date(), in: timeZone)
        let hour = max(DayClock.resetHour, min(overrideHour, DayClock.resetHour + 23))
        return DayClock.date(of: real.day, hour: hour, minute: 12, in: timeZone)
    }

    var currentSlot: Slot { DayClock.slot(for: now, in: timeZone) }
    var today: DayKey { currentSlot.day }

    /// Seconds until the next ping in a room, or until the next slot if the ping has
    /// passed.
    func secondsUntilPing(room roomID: String) -> TimeInterval {
        let slot = currentSlot
        let ping = SlotPing.fireDate(room: roomID, slot: slot, in: timeZone)
        if ping > now { return ping.timeIntervalSince(now) }
        let next = DayClock.nextSlot(after: now, in: timeZone)
        return SlotPing.fireDate(room: roomID, slot: next, in: timeZone).timeIntervalSince(now)
    }

    func formatted(_ day: DayKey) -> String {
        let date = DayClock.date(of: day, hour: 12, minute: 0, in: timeZone)
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// `23m`, `1h 05m`.
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        return String(format: "%dm", max(1, minutes))
    }
}
