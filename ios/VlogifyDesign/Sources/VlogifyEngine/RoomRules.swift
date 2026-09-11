import Foundation

/// The four kinds of room. Only `log` and `vlog` are reachable in v1; `stack` and
/// `zip` are modelled so the wire format and the database never need a migration to
/// add them, and hidden behind `FeatureFlags` in the app until they are built.
public enum RoomType: String, Codable, CaseIterable, Sendable {
    /// You and friends, one two-second clip per hour, stitched at day's end.
    case log
    /// A rolling 24-hour feed for up to forty people. Same clips, no per-hour grid.
    case stack
    /// Just you. No hour limit, no clip cap, no ping.
    case vlog
    /// A one-to-one, view-once photo with a caption. "Logs are for your day. Zips are
    /// for right now."
    case zip
}

/// Everything about a room that is a rule rather than data. Lives here so the server
/// can never grow its own idea of "full" that disagrees with the app.
public enum RoomRules {
    /// The size pills on the new-room sheet, in order. The last option for a log is
    /// the "6-20" pill, which sets the cap to twenty.
    public static func capacityOptions(for type: RoomType) -> [Int] {
        switch type {
        case .log: return [2, 3, 4, 5, 20]
        case .stack: return [40]
        case .vlog: return [1]
        case .zip: return [2]
        }
    }

    public static func defaultCapacity(for type: RoomType) -> Int {
        switch type {
        case .log: return 3
        case .stack: return 40
        case .vlog: return 1
        case .zip: return 2
        }
    }

    public static func maxCapacity(for type: RoomType) -> Int {
        capacityOptions(for: type).max() ?? 1
    }

    public static func isValidCapacity(_ capacity: Int, for type: RoomType) -> Bool {
        switch type {
        case .log: return (2...20).contains(capacity)
        case .stack: return (2...40).contains(capacity)
        case .vlog: return capacity == 1
        case .zip: return capacity == 2
        }
    }

    /// The pill label: `2`, `3`, `4`, `5`, `6-20`.
    public static func capacityLabel(_ capacity: Int, for type: RoomType) -> String {
        if type == .log, capacity == 20 { return "6-20" }
        return String(capacity)
    }

    /// Clip length in seconds. `nil` means unlimited.
    public static func clipLimit(for type: RoomType) -> Double? {
        switch type {
        case .log, .stack: return 2.0
        case .vlog, .zip: return nil
        }
    }

    /// How many clips one member may post into one slot. `nil` means unlimited.
    public static func capturesPerSlot(for type: RoomType) -> Int? {
        switch type {
        case .log, .stack: return 1
        case .vlog, .zip: return nil
        }
    }

    /// Whether the room pings its members on the hour.
    public static func pings(_ type: RoomType) -> Bool {
        type == .log || type == .stack
    }

    /// One take. The whole product is the candid; a retake is a pose.
    public static let canRetake = false

    /// Room names are optional and short. The cap matches what fits on a card title.
    public static let maxNameLength = 24

    public static func normalizedName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    /// Whether another member can join.
    public static func canJoin(memberCount: Int, capacity: Int) -> Bool {
        memberCount < capacity
    }
}
