import Foundation

/// Where every member's clip goes on the exported canvas, and when.
///
/// Pure geometry so it can be tested on the command line and drawn by both the
/// SwiftUI player and the AVFoundation compositor from one source. Rects are
/// normalised (0...1) so the same plan serves a 1080x1920 export and a thumbnail.
public struct StitchPlan: Equatable, Sendable {
    /// One member's tile.
    public struct Tile: Equatable, Sendable {
        public let memberIndex: Int
        /// Normalised, origin top-left.
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
    }

    /// One hour of the exported day.
    public struct Segment: Equatable, Sendable {
        public let slot: Slot
        public let start: Double
        public let duration: Double
    }

    public static let exportWidth = 1080
    public static let exportHeight = 1920

    public let memberCount: Int
    public let tiles: [Tile]

    public init(memberCount: Int) {
        let count = max(1, min(memberCount, 20))
        self.memberCount = count
        self.tiles = StitchPlan.layout(for: count)
    }

    /// Columns and rows for a member count. Every tile is portrait or square -- these
    /// are phone clips, and a landscape tile of a portrait clip is mostly letterbox.
    /// Two or three people are vertical strips, side by side: the tagline, literally.
    public static func grid(for count: Int) -> (columns: Int, rows: Int) {
        switch count {
        case ...1: return (1, 1)
        case 2: return (2, 1)
        case 3: return (3, 1)
        case 4: return (2, 2)
        case 5...6: return (2, 3)
        case 7...9: return (3, 3)
        case 10...12: return (3, 4)
        case 13...16: return (4, 4)
        default: return (4, 5)
        }
    }

    static func layout(for count: Int) -> [Tile] {
        let (columns, rows) = grid(for: count)
        let width = 1.0 / Double(columns)
        let height = 1.0 / Double(rows)
        return (0..<count).map { index in
            let column = index % columns
            let row = index / columns
            return Tile(memberIndex: index,
                        x: Double(column) * width, y: Double(row) * height,
                        width: width, height: height)
        }
    }

    /// The exported timeline: one segment per slot that has at least one clip, in
    /// order, each `clipDuration` long. Empty hours are skipped -- a day with six
    /// posts is a twelve-second video, not a forty-eight-second one with gaps.
    public static func segments(for slots: [Slot], clipDuration: Double) -> [Segment] {
        slots.sorted().enumerated().map { index, slot in
            Segment(slot: slot, start: Double(index) * clipDuration, duration: clipDuration)
        }
    }

    public static func totalDuration(slotCount: Int, clipDuration: Double) -> Double {
        Double(slotCount) * clipDuration
    }
}
