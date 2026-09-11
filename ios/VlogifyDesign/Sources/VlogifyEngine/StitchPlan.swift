import Foundation

/// Where every member's clip goes on the exported canvas, and when.
///
/// Pure geometry so it can be tested on the command line and drawn by both the
/// SwiftUI player and the AVFoundation compositor from one source. Rects are
/// normalised (0...1) so the same plan serves a 1080x1920 export and a thumbnail.
public struct StitchPlan: Equatable, Sendable {
    /// Which way the clips were shot. Landscape is the default: most people turn the
    /// phone, and landscape clips stack into rows on a vertical canvas -- which is
    /// what "side by side" looks like when it is posted to Reels or Shorts.
    public enum Orientation: String, Codable, Sendable {
        case landscape, portrait
    }

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
    public let orientation: Orientation
    public let tiles: [Tile]

    public init(memberCount: Int, orientation: Orientation = .landscape) {
        let count = max(1, min(memberCount, 20))
        self.memberCount = count
        self.orientation = orientation
        self.tiles = StitchPlan.layout(for: count, orientation: orientation)
    }

    /// Columns and rows for a member count.
    ///
    /// Landscape clips stack as full-width rows for up to four people, then two
    /// columns; a tile never gets taller than it is wide until there are five in the
    /// room. Portrait clips do the opposite: vertical strips side by side, never a
    /// landscape tile. Either way the canvas stays 1080x1920 so the export is ready
    /// for a vertical feed.
    public static func grid(for count: Int, orientation: Orientation = .landscape) -> (columns: Int, rows: Int) {
        switch orientation {
        case .landscape:
            switch count {
            case ...1: return (1, 1)
            case 2: return (1, 2)
            case 3: return (1, 3)
            case 4: return (1, 4)
            case 5...6: return (2, 3)
            case 7...8: return (2, 4)
            case 9...10: return (2, 5)
            case 11...12: return (2, 6)
            case 13...15: return (3, 5)
            case 16...18: return (3, 6)
            default: return (4, 5)
            }
        case .portrait:
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
    }

    static func layout(for count: Int, orientation: Orientation) -> [Tile] {
        let (columns, rows) = grid(for: count, orientation: orientation)
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
