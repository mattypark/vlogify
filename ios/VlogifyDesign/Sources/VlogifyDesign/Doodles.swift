import SwiftUI

/// Every drawing in the app, drawn in code with the same pen as everything else.
///
/// There are no image assets and no artist slots: each doodle is a handful of strokes in
/// a unit square, built from lines, arcs and curves with a little seeded tremor so no
/// two lines are ruler-straight. The same `InkStrokes` renderer draws them and the marks
/// people draw themselves, so a doodle and a person's mark sit on the page as the same
/// kind of thing -- and every doodle can draw itself on screen, stroke by stroke.
///
/// The set is about recording: a clock, a phone buzzing, clips side by side, a camera,
/// the nudge, the 4 AM moon, friends, a page. Arrows and marks for annotations.
public enum Doodle: String, CaseIterable, Sendable {
    // Onboarding and empty states
    case clock, phoneBuzz, frames, camcorder, bell, moon, friends, page
    // Annotations
    case arrowDownRight, arrowDownLeft, arrowDown, arrowUpLeft, arrowTurn
    // Glyphs
    case check, plus, cross, undo, sparkle, heart
    case arrowLeft, arrowRight, play, hash, pencil

    /// The design size in points.
    public var size: CGSize {
        switch self {
        case .clock, .bell, .moon, .camcorder: CGSize(width: 150, height: 150)
        case .phoneBuzz: CGSize(width: 150, height: 170)
        case .frames: CGSize(width: 220, height: 130)
        case .friends: CGSize(width: 190, height: 120)
        case .page: CGSize(width: 110, height: 140)
        case .arrowDownRight, .arrowDownLeft, .arrowUpLeft: CGSize(width: 56, height: 48)
        case .arrowDown: CGSize(width: 28, height: 56)
        case .arrowTurn: CGSize(width: 44, height: 44)
        case .arrowLeft, .arrowRight: CGSize(width: 40, height: 24)
        case .check, .plus, .cross, .undo, .sparkle, .heart, .play, .hash, .pencil: CGSize(width: 24, height: 24)
        }
    }

    /// The strokes, in a unit square (y down), in the order a hand would draw them.
    public var strokes: [[CGPoint]] {
        var pen = DoodlePen(seed: rawValue)
        switch self {
        case .clock:
            return [
                pen.arc(center: (0.5, 0.53), radius: 0.4, from: -100, to: 268),
                pen.line((0.5, 0.53), (0.5, 0.3)),
                pen.line((0.5, 0.53), (0.67, 0.61)),
                pen.line((0.5, 0.17), (0.5, 0.22)),
                pen.line((0.86, 0.53), (0.81, 0.53)),
                pen.line((0.5, 0.89), (0.5, 0.84)),
                pen.line((0.14, 0.53), (0.19, 0.53)),
            ]
        case .phoneBuzz:
            return [
                pen.roundedRect(x: 0.33, y: 0.1, w: 0.34, h: 0.8, r: 0.07),
                pen.line((0.45, 0.17), (0.55, 0.17)),
                pen.arc(center: (0.33, 0.5), radius: 0.12, from: 145, to: 215),
                pen.arc(center: (0.33, 0.5), radius: 0.2, from: 150, to: 210),
                pen.arc(center: (0.67, 0.5), radius: 0.12, from: -35, to: 35),
                pen.arc(center: (0.67, 0.5), radius: 0.2, from: -30, to: 30),
            ]
        case .frames:
            return [
                pen.roundedRect(x: 0.04, y: 0.12, w: 0.28, h: 0.76, r: 0.04),
                pen.roundedRect(x: 0.36, y: 0.12, w: 0.28, h: 0.76, r: 0.04),
                pen.roundedRect(x: 0.68, y: 0.12, w: 0.28, h: 0.76, r: 0.04),
                // A face, a little house, a heart: three friends' hours.
                pen.arc(center: (0.18, 0.46), radius: 0.07, from: 0, to: 360),
                pen.line((0.18, 0.53), (0.18, 0.7)),
                pen.polyline([(0.42, 0.52), (0.5, 0.36), (0.58, 0.52)]),
                pen.polyline([(0.44, 0.5), (0.44, 0.7), (0.56, 0.7), (0.56, 0.5)]),
                pen.heart(center: (0.82, 0.52), size: 0.12),
            ]
        case .camcorder:
            return [
                pen.roundedRect(x: 0.1, y: 0.38, w: 0.56, h: 0.4, r: 0.06),
                pen.polyline([(0.66, 0.5), (0.9, 0.38), (0.9, 0.78), (0.66, 0.66)]),
                pen.arc(center: (0.26, 0.26), radius: 0.11, from: 0, to: 360),
                pen.arc(center: (0.5, 0.26), radius: 0.11, from: 0, to: 360),
                pen.arc(center: (0.2, 0.48), radius: 0.025, from: 0, to: 360),
            ]
        case .bell:
            return [
                pen.curve((0.26, 0.72), (0.34, 0.66), (0.28, 0.2), (0.5, 0.2)),
                pen.curve((0.5, 0.2), (0.72, 0.2), (0.66, 0.66), (0.74, 0.72)),
                pen.line((0.22, 0.73), (0.78, 0.73)),
                pen.arc(center: (0.5, 0.8), radius: 0.05, from: 0, to: 360),
                pen.line((0.5, 0.2), (0.5, 0.14)),
                pen.arc(center: (0.5, 0.45), radius: 0.36, from: 200, to: 235),
                pen.arc(center: (0.5, 0.45), radius: 0.36, from: -55, to: -20),
            ]
        case .moon:
            return [
                pen.arc(center: (0.48, 0.52), radius: 0.34, from: 55, to: 305),
                pen.arc(center: (0.8, 0.52), radius: 0.306, from: 246, to: 114, clockwise: false),
            ] + pen.sparkle(center: (0.8, 0.2), size: 0.08) + pen.sparkle(center: (0.9, 0.42), size: 0.05)
        case .friends:
            return [
                pen.arc(center: (0.2, 0.4), radius: 0.1, from: 0, to: 360),
                pen.arc(center: (0.2, 0.82), radius: 0.17, from: 190, to: 350),
                pen.arc(center: (0.5, 0.32), radius: 0.12, from: 0, to: 360),
                pen.arc(center: (0.5, 0.82), radius: 0.2, from: 190, to: 350),
                pen.arc(center: (0.8, 0.4), radius: 0.1, from: 0, to: 360),
                pen.arc(center: (0.8, 0.82), radius: 0.17, from: 190, to: 350),
            ]
        case .page:
            return [
                pen.polyline([(0.66, 0.1), (0.2, 0.1), (0.2, 0.9), (0.8, 0.9), (0.8, 0.24), (0.66, 0.1)]),
                pen.polyline([(0.66, 0.1), (0.66, 0.24), (0.8, 0.24)]),
                pen.line((0.3, 0.42), (0.7, 0.42)),
                pen.line((0.3, 0.54), (0.7, 0.54)),
                pen.line((0.3, 0.66), (0.55, 0.66)),
            ]
        case .arrowDownRight:
            return pen.arrow(pen.curve((0.06, 0.12), (0.3, 0.1), (0.6, 0.3), (0.88, 0.86)))
        case .arrowDownLeft:
            return pen.arrow(pen.curve((0.94, 0.12), (0.7, 0.1), (0.4, 0.3), (0.12, 0.86)))
        case .arrowUpLeft:
            return pen.arrow(pen.curve((0.92, 0.9), (0.66, 0.9), (0.3, 0.72), (0.1, 0.16)))
        case .arrowDown:
            return pen.arrow(pen.curve((0.5, 0.04), (0.3, 0.3), (0.72, 0.6), (0.5, 0.94)))
        case .arrowTurn:
            return pen.arrow(pen.arc(center: (0.5, 0.5), radius: 0.36, from: -60, to: 230))
        case .check:
            return [pen.polyline([(0.14, 0.54), (0.4, 0.8), (0.88, 0.18)])]
        case .plus:
            return [pen.line((0.5, 0.12), (0.5, 0.88)), pen.line((0.12, 0.5), (0.88, 0.5))]
        case .cross:
            return [pen.line((0.18, 0.18), (0.82, 0.82)), pen.line((0.82, 0.18), (0.18, 0.82))]
        case .undo:
            return pen.arrow(pen.curve((0.84, 0.82), (0.9, 0.36), (0.5, 0.2), (0.12, 0.4)))
        case .sparkle:
            return pen.sparkle(center: (0.5, 0.5), size: 0.42)
        case .heart:
            return [pen.heart(center: (0.5, 0.52), size: 0.4)]
        case .arrowLeft:
            return pen.arrow(pen.curve((0.94, 0.56), (0.7, 0.44), (0.36, 0.6), (0.06, 0.48)))
        case .arrowRight:
            return pen.arrow(pen.curve((0.06, 0.56), (0.3, 0.44), (0.64, 0.6), (0.94, 0.48)))
        case .play:
            return [pen.polyline([(0.28, 0.16), (0.28, 0.84), (0.82, 0.5), (0.26, 0.18)])]
        case .hash:
            return [
                pen.line((0.4, 0.12), (0.32, 0.88)),
                pen.line((0.7, 0.12), (0.62, 0.88)),
                pen.line((0.14, 0.36), (0.88, 0.36)),
                pen.line((0.12, 0.64), (0.86, 0.64)),
            ]
        case .pencil:
            return [
                pen.polyline([(0.2, 0.62), (0.66, 0.16), (0.84, 0.34), (0.38, 0.8), (0.14, 0.86), (0.2, 0.62)]),
                pen.line((0.58, 0.24), (0.76, 0.42)),
            ]
        }
    }
}

public extension Doodle {
    /// The clock with its hands at a real time -- the big drawing on the home page. The
    /// face is the onboarding clock's own face, so the two read as the same drawing.
    static func clock(hour: Int, minute: Int) -> [[CGPoint]] {
        var pen = DoodlePen(seed: Doodle.clock.rawValue)
        let center = (0.5, 0.53)
        let face = pen.arc(center: center, radius: 0.4, from: -100, to: 268)
        var hands = DoodlePen(seed: "clock.\(hour % 12).\(minute)")
        func hand(degrees: Double, length: Double) -> [CGPoint] {
            let angle = (degrees - 90) * .pi / 180
            return hands.line(center, (center.0 + cos(angle) * length, center.1 + sin(angle) * length))
        }
        let minutes = Double(max(0, min(minute, 59)))
        return [
            face,
            hand(degrees: (Double(hour % 12) + minutes / 60) * 30, length: 0.19),
            hand(degrees: minutes * 6, length: 0.27),
            pen.line((0.5, 0.17), (0.5, 0.22)),
            pen.line((0.86, 0.53), (0.81, 0.53)),
            pen.line((0.5, 0.89), (0.5, 0.84)),
            pen.line((0.14, 0.53), (0.19, 0.53)),
        ]
    }
}

public extension Doodle {
    /// The ink's own extent plus a pen's width of margin, so a tall arrow fills a tall
    /// frame instead of being fitted as a unit square.
    var box: CGRect {
        let points = strokes.flatMap { $0 }
        guard let first = points.first else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let margin: CGFloat = 0.03
        return CGRect(x: minX - margin, y: minY - margin,
                      width: max(maxX - minX, 0.05) + margin * 2, height: max(maxY - minY, 0.05) + margin * 2)
    }
}

/// A doodle at its design size, optionally drawing itself.
public struct DoodleSticker: View {
    private let doodle: Doodle
    private let scale: CGFloat
    private let animated: Bool
    private let lineWidth: CGFloat
    private let color: Color
    private let delay: Double

    public init(_ doodle: Doodle, scale: CGFloat = 1, animated: Bool = false,
                lineWidth: CGFloat = Pen.line, color: Color = .text, delay: Double = 0) {
        self.doodle = doodle
        self.scale = scale
        self.animated = animated
        self.lineWidth = lineWidth
        self.color = color
        self.delay = delay
    }

    public var body: some View {
        InkDrawing(doodle.strokes, box: doodle.box, color: color, lineWidth: lineWidth,
                   duration: 0.5 + Double(doodle.strokes.count) * 0.12, delay: delay, animated: animated)
            .frame(width: doodle.size.width * scale, height: doodle.size.height * scale)
    }
}

/// Builds hand-drawn strokes: densified so the tremor has points to move, and nudged by
/// a seeded amount so the same doodle draws the same way on every launch.
struct DoodlePen {
    private var random: SplitMix
    private let tremor = 0.006

    init(seed: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 { hash ^= UInt64(byte); hash = hash &* 0x0000_0100_0000_01b3 }
        random = SplitMix(seed: hash)
    }

    private mutating func shake(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x + (random.next() - 0.5) * 2 * tremor, y: y + (random.next() - 0.5) * 2 * tremor)
    }

    mutating func line(_ a: (Double, Double), _ b: (Double, Double)) -> [CGPoint] {
        let length = ((b.0 - a.0) * (b.0 - a.0) + (b.1 - a.1) * (b.1 - a.1)).squareRoot()
        let steps = max(2, Int(length / 0.05))
        return (0...steps).map { step in
            let t = Double(step) / Double(steps)
            return shake(a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t)
        }
    }

    mutating func polyline(_ points: [(Double, Double)]) -> [CGPoint] {
        var result: [CGPoint] = []
        for index in 0..<(points.count - 1) {
            let segment = line(points[index], points[index + 1])
            result.append(contentsOf: index == 0 ? segment : Array(segment.dropFirst()))
        }
        return result
    }

    /// Degrees, 0 = east, clockwise on screen (y down).
    mutating func arc(center: (Double, Double), radius: Double, from: Double, to: Double, clockwise: Bool = true) -> [CGPoint] {
        var end = to
        if clockwise, end < from { end += 360 }
        if !clockwise, end > from { end -= 360 }
        let span = abs(end - from)
        let steps = max(6, Int(span / 9))
        return (0...steps).map { step in
            let angle = (from + (end - from) * Double(step) / Double(steps)) * .pi / 180
            return shake(center.0 + cos(angle) * radius, center.1 + sin(angle) * radius)
        }
    }

    mutating func curve(_ p0: (Double, Double), _ c1: (Double, Double), _ c2: (Double, Double), _ p3: (Double, Double)) -> [CGPoint] {
        (0...22).map { step in
            let t = Double(step) / 22, u = 1 - t
            let x = u * u * u * p0.0 + 3 * u * u * t * c1.0 + 3 * u * t * t * c2.0 + t * t * t * p3.0
            let y = u * u * u * p0.1 + 3 * u * u * t * c1.1 + 3 * u * t * t * c2.1 + t * t * t * p3.1
            return shake(x, y)
        }
    }

    mutating func roundedRect(x: Double, y: Double, w: Double, h: Double, r: Double) -> [CGPoint] {
        var points: [CGPoint] = []
        points += line((x + r, y), (x + w - r, y))
        points += arc(center: (x + w - r, y + r), radius: r, from: -90, to: 0).dropFirst()
        points += line((x + w, y + r), (x + w, y + h - r)).dropFirst()
        points += arc(center: (x + w - r, y + h - r), radius: r, from: 0, to: 90).dropFirst()
        points += line((x + w - r, y + h), (x + r, y + h)).dropFirst()
        points += arc(center: (x + r, y + h - r), radius: r, from: 90, to: 180).dropFirst()
        points += line((x, y + h - r), (x, y + r)).dropFirst()
        points += arc(center: (x + r, y + r), radius: r, from: 180, to: 270).dropFirst()
        // Run past the start, the way a hand closes a box.
        points += line((x + r, y), (x + r + min(w * 0.18, 0.06), y + 0.008)).dropFirst()
        return points
    }

    mutating func heart(center: (Double, Double), size s: Double) -> [CGPoint] {
        let (cx, cy) = center
        return curve((cx, cy + s), (cx - s * 1.6, cy - s * 0.1), (cx - s * 0.6, cy - s * 1.1), (cx, cy - s * 0.35))
            + curve((cx, cy - s * 0.35), (cx + s * 0.6, cy - s * 1.1), (cx + s * 1.6, cy - s * 0.1), (cx, cy + s)).dropFirst()
    }

    mutating func sparkle(center: (Double, Double), size s: Double) -> [[CGPoint]] {
        let (cx, cy) = center
        return [line((cx, cy - s), (cx, cy + s)), line((cx - s, cy), (cx + s, cy))]
    }

    /// A stroke with an arrowhead at its end, pointing the way the stroke was going.
    mutating func arrow(_ shaft: [CGPoint]) -> [[CGPoint]] {
        guard shaft.count >= 2 else { return [shaft] }
        let tip = shaft[shaft.count - 1]
        let back = shaft[max(0, shaft.count - 4)]
        let angle = atan2(Double(tip.y - back.y), Double(tip.x - back.x))
        let length = 0.2
        func barb(_ turn: Double) -> (Double, Double) {
            (Double(tip.x) - cos(angle + turn) * length, Double(tip.y) - sin(angle + turn) * length)
        }
        let tipPair = (Double(tip.x), Double(tip.y))
        return [shaft, polyline([barb(0.5), tipPair, barb(-0.5)])]
    }
}
