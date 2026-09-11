import Foundation

/// A calendar day as the app counts it: it starts at 4 AM, not midnight.
///
/// A night out that runs past midnight is still "today" to the people in it, and
/// Setlog's own home screen says so ("day resets at 4AM"). Everything that groups clips
/// -- the room timeline, history, the stitched export, the notification schedule --
/// keys off this type and never off `Calendar`'s idea of a day.
public struct DayKey: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// `2026-09-11`. Sortable as text, which is what the wire format and the on-disk
    /// cache both rely on.
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Parses `2026-09-11`.
    public init?(_ string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// On the wire and on disk a day is its ISO string, not a three-field object.
extension DayKey: Codable {
    public init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(string) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad day key \(string)"))
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// One hour of one app-day. `hour` runs 4...27: 4 is 4 AM, 23 is 11 PM, 24 is midnight
/// and 27 is 3 AM of the following calendar morning, still inside the same `DayKey`.
public struct Slot: Hashable, Codable, Sendable, Comparable {
    public let day: DayKey
    public let hour: Int

    public init(day: DayKey, hour: Int) {
        precondition((DayClock.resetHour..<(DayClock.resetHour + 24)).contains(hour),
                     "slot hour must be \(DayClock.resetHour)...\(DayClock.resetHour + 23)")
        self.day = day
        self.hour = hour
    }

    /// The wall-clock hour, 0...23.
    public var clockHour: Int { hour % 24 }

    /// Position within the day, 0...23. Row index on the timeline.
    public var index: Int { hour - DayClock.resetHour }

    /// The label on a tile: `4:00`, `12:00`, `1:00`. Twelve-hour, no meridiem -- the
    /// timeline is chronological so the reader already knows which one it is.
    public var label: String {
        let twelve = clockHour % 12
        return "\(twelve == 0 ? 12 : twelve):00"
    }

    /// Stable identifier for storage keys and notification ids.
    public var key: String { "\(day)/\(hour)" }

    public static func < (lhs: Slot, rhs: Slot) -> Bool {
        lhs.day == rhs.day ? lhs.hour < rhs.hour : lhs.day < rhs.day
    }
}

/// The only clock the app trusts.
///
/// Every conversion goes through wall-clock components in the user's time zone rather
/// than through seconds arithmetic, so a daylight-saving jump moves a slot's boundary
/// with the clock on the wall instead of leaving a 5 AM slot that starts at 4.
public enum DayClock {
    /// The app-day boundary. Not configurable: it is part of the product's contract
    /// with the server, which computes the same `DayKey` for the same instant.
    public static let resetHour = 4

    public static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    public static func dayKey(for date: Date, in timeZone: TimeZone) -> DayKey {
        slot(for: date, in: timeZone).day
    }

    public static func slot(for date: Date, in timeZone: TimeZone) -> Slot {
        let calendar = calendar(in: timeZone)
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        var hour = components.hour ?? 0
        if hour < resetHour {
            // Small hours belong to the day that started the previous afternoon.
            let previous = calendar.date(byAdding: .day, value: -1,
                                         to: calendar.date(from: components) ?? date) ?? date
            components = calendar.dateComponents([.year, .month, .day], from: previous)
            hour += 24
        }
        return Slot(day: DayKey(year: components.year ?? 0, month: components.month ?? 0,
                                day: components.day ?? 0), hour: hour)
    }

    /// All twenty-four slots of a day, in order.
    public static func slots(of day: DayKey) -> [Slot] {
        (resetHour..<(resetHour + 24)).map { Slot(day: day, hour: $0) }
    }

    /// The instant a slot begins, on the wall clock.
    public static func start(of slot: Slot, in timeZone: TimeZone) -> Date {
        date(of: slot.day, hour: slot.hour, minute: 0, in: timeZone)
    }

    public static func end(of slot: Slot, in timeZone: TimeZone) -> Date {
        date(of: slot.day, hour: slot.hour + 1, minute: 0, in: timeZone)
    }

    /// A wall-clock instant inside an app-day. `hour` may exceed 23, meaning the next
    /// calendar morning.
    public static func date(of day: DayKey, hour: Int, minute: Int, in timeZone: TimeZone) -> Date {
        let calendar = calendar(in: timeZone)
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day + hour / 24
        components.hour = hour % 24
        components.minute = minute
        // `Calendar` normalises day overflow (Sept 31 -> Oct 1) and resolves a wall
        // time that does not exist on a spring-forward morning to the next valid one.
        return calendar.date(from: components) ?? Date()
    }

    public static func nextSlot(after date: Date, in timeZone: TimeZone) -> Slot {
        let current = slot(for: date, in: timeZone)
        if current.hour < resetHour + 23 {
            return Slot(day: current.day, hour: current.hour + 1)
        }
        let nextDay = dayKey(for: end(of: current, in: timeZone), in: timeZone)
        return Slot(day: nextDay, hour: resetHour)
    }

    /// This slot and every later one in the same day. What the notification
    /// scheduler plans on each foreground.
    public static func remainingSlots(from date: Date, in timeZone: TimeZone) -> [Slot] {
        let current = slot(for: date, in: timeZone)
        return slots(of: current.day).filter { $0.hour >= current.hour }
    }
}
