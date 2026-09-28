import Foundation

/// One point of a mark, in the unit square of the canvas it was drawn on: (0, 0) is
/// the top-left corner, (1, 1) the bottom-right.
public struct MarkPoint: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// The doodle a person draws during onboarding. It is who they are in vlogify: their
/// avatar, the badge on their clips, the signature on their square of the nightly vlog.
///
/// On the wire it is one short string, so it rides on `Profile` like a name does and
/// the backend stores it as a column without understanding it:
///
///     base64url( version:u8 = 1, then per stroke: count:u8, count × (x:u8, y:u8) )
///
/// Coordinates are quantised to 256 steps. A mark is drawn on a phone-width square and
/// shown at avatar size, so a step is about 1.3 pt at the size it was drawn and
/// invisible anywhere smaller. The caps keep the worst case under 1.8 KB of text; a
/// mark over them is simplified until it fits rather than refused, because the person
/// only ever sees "draw something" and should never meet a byte limit.
public struct Mark: Hashable, Sendable {
    public static let version: UInt8 = 1
    public static let maxStrokes = 64
    public static let maxPoints = 640
    /// Upper bound on `encoded.count`. The backend rejects anything longer.
    public static let maxEncodedLength = 1_800

    public let strokes: [[MarkPoint]]

    /// Clamps to the unit square, quantises, drops empty strokes, and simplifies until
    /// the caps hold. The stored strokes are exactly what `encoded` round-trips to.
    public init(strokes raw: [[MarkPoint]]) {
        var strokes = raw
            .map { stroke in stroke.map { MarkPoint(x: Self.clamp($0.x), y: Self.clamp($0.y)) } }
            .filter { !$0.isEmpty }
        if strokes.count > Self.maxStrokes {
            strokes = Array(strokes.prefix(Self.maxStrokes))
        }
        var tolerance = 0.002
        while Self.pointCount(of: Self.quantised(strokes)) > Self.maxPoints {
            strokes = strokes.map { Self.simplify($0, tolerance: tolerance) }
            tolerance *= 1.6
        }
        // Splitting a stroke longer than a u8 can count adds strokes; the cap is on
        // what goes over the wire.
        self.strokes = Array(Self.quantised(strokes).prefix(Self.maxStrokes))
    }

    public var isEmpty: Bool { strokes.isEmpty }

    public var pointCount: Int { Self.pointCount(of: strokes) }

    /// The wire form. base64url, no padding.
    public var encoded: String {
        var bytes: [UInt8] = [Self.version]
        for stroke in strokes {
            bytes.append(UInt8(stroke.count))
            for point in stroke {
                bytes.append(Self.byte(point.x))
                bytes.append(Self.byte(point.y))
            }
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Nil for anything that is not a well-formed version-1 mark within the caps.
    public init?(encoded: String) {
        guard !encoded.isEmpty, encoded.count <= Self.maxEncodedLength else { return nil }
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64) else { return nil }
        let bytes = [UInt8](data)
        guard bytes.first == Self.version else { return nil }
        var index = 1
        var strokes: [[MarkPoint]] = []
        while index < bytes.count {
            let count = Int(bytes[index])
            index += 1
            guard count > 0, index + count * 2 <= bytes.count else { return nil }
            var stroke: [MarkPoint] = []
            stroke.reserveCapacity(count)
            for offset in 0..<count {
                let x = Double(bytes[index + offset * 2]) / 255
                let y = Double(bytes[index + offset * 2 + 1]) / 255
                stroke.append(MarkPoint(x: x, y: y))
            }
            index += count * 2
            strokes.append(stroke)
        }
        guard !strokes.isEmpty, strokes.count <= Self.maxStrokes,
              Self.pointCount(of: strokes) <= Self.maxPoints else { return nil }
        self.strokes = strokes
    }

    /// The smallest box holding every point, for renderers that fit the ink rather than
    /// the canvas. A single dot gets a small square around it so it still has a size.
    public var bounds: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        let points = strokes.flatMap { $0 }
        guard let first = points.first else { return (0, 0, 1, 1) }
        var box = (minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
        for point in points.dropFirst() {
            box.minX = min(box.minX, point.x)
            box.minY = min(box.minY, point.y)
            box.maxX = max(box.maxX, point.x)
            box.maxY = max(box.maxY, point.y)
        }
        if box.maxX - box.minX < 0.02 { box.minX -= 0.01; box.maxX += 0.01 }
        if box.maxY - box.minY < 0.02 { box.minY -= 0.01; box.maxY += 0.01 }
        return box
    }

    // MARK: Internals

    static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    static func byte(_ value: Double) -> UInt8 {
        UInt8((clamp(value) * 255).rounded())
    }

    static func pointCount(of strokes: [[MarkPoint]]) -> Int {
        strokes.reduce(0) { $0 + $1.count }
    }

    /// Snaps to the wire grid, drops consecutive duplicates, and splits any stroke
    /// longer than a u8 can count into pieces that share their joining point.
    static func quantised(_ strokes: [[MarkPoint]]) -> [[MarkPoint]] {
        var result: [[MarkPoint]] = []
        for stroke in strokes {
            var snapped: [MarkPoint] = []
            for point in stroke {
                let grid = MarkPoint(x: Double(byte(point.x)) / 255, y: Double(byte(point.y)) / 255)
                if snapped.last != grid { snapped.append(grid) }
            }
            guard !snapped.isEmpty else { continue }
            var start = 0
            while start < snapped.count {
                let end = min(start + 255, snapped.count)
                result.append(Array(snapped[start..<end]))
                if end == snapped.count { break }
                start = end - 1
            }
        }
        return result
    }

    /// Ramer–Douglas–Peucker. Keeps the endpoints; drops points closer than
    /// `tolerance` to the line between their neighbours.
    static func simplify(_ stroke: [MarkPoint], tolerance: Double) -> [MarkPoint] {
        guard stroke.count > 2 else { return stroke }
        var keep = [Bool](repeating: false, count: stroke.count)
        keep[0] = true
        keep[stroke.count - 1] = true
        var stack = [(0, stroke.count - 1)]
        while let (first, last) = stack.popLast() {
            var farthest = 0.0
            var index = first
            for candidate in (first + 1)..<last {
                let distance = perpendicular(stroke[candidate], stroke[first], stroke[last])
                if distance > farthest {
                    farthest = distance
                    index = candidate
                }
            }
            if farthest > tolerance, index != first {
                keep[index] = true
                stack.append((first, index))
                stack.append((index, last))
            }
        }
        return stroke.enumerated().filter { keep[$0.offset] }.map(\.element)
    }

    static func perpendicular(_ point: MarkPoint, _ start: MarkPoint, _ end: MarkPoint) -> Double {
        let dx = end.x - start.x, dy = end.y - start.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else {
            return ((point.x - start.x) * (point.x - start.x) + (point.y - start.y) * (point.y - start.y)).squareRoot()
        }
        return abs(dy * point.x - dx * point.y + end.x * start.y - end.y * start.x) / length
    }
}

extension Mark: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let mark = Mark(encoded: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "not a version-1 mark")
        }
        self = mark
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(encoded)
    }
}

public extension Mark {
    /// Marks for the seeded demo people. Drawn in code so a screenshot of a room shows
    /// what a room of real people looks like: every member a different little doodle.
    static func sample(_ index: Int) -> Mark {
        func ring(cx: Double, cy: Double, r: Double, from: Double = 0, to: Double = 2 * .pi, steps: Int = 28) -> [MarkPoint] {
            (0...steps).map { step in
                let angle = from + (to - from) * Double(step) / Double(steps)
                return MarkPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
            }
        }
        switch ((index % 4) + 4) % 4 {
        case 0:
            // A face: a circle, two dots, a smile.
            return Mark(strokes: [
                ring(cx: 0.5, cy: 0.5, r: 0.36),
                [MarkPoint(x: 0.38, y: 0.42)],
                [MarkPoint(x: 0.62, y: 0.42)],
                ring(cx: 0.5, cy: 0.52, r: 0.16, from: 0.3, to: .pi - 0.3, steps: 12),
            ])
        case 1:
            // A five-point star in one stroke.
            let star = (0...5).map { step -> MarkPoint in
                let angle = -Double.pi / 2 + Double(step) * 4 * .pi / 5
                return MarkPoint(x: 0.5 + cos(angle) * 0.4, y: 0.52 + sin(angle) * 0.4)
            }
            return Mark(strokes: [star])
        case 2:
            // A spiral.
            let spiral = (0...60).map { step -> MarkPoint in
                let t = Double(step) / 60
                let angle = t * 5 * .pi
                return MarkPoint(x: 0.5 + cos(angle) * 0.4 * t, y: 0.5 + sin(angle) * 0.4 * t)
            }
            return Mark(strokes: [spiral])
        default:
            // A little house.
            return Mark(strokes: [
                [MarkPoint(x: 0.2, y: 0.5), MarkPoint(x: 0.5, y: 0.18), MarkPoint(x: 0.8, y: 0.5)],
                [MarkPoint(x: 0.28, y: 0.44), MarkPoint(x: 0.28, y: 0.84), MarkPoint(x: 0.72, y: 0.84), MarkPoint(x: 0.72, y: 0.44)],
                [MarkPoint(x: 0.44, y: 0.84), MarkPoint(x: 0.44, y: 0.64), MarkPoint(x: 0.56, y: 0.64), MarkPoint(x: 0.56, y: 0.84)],
            ])
        }
    }
}
