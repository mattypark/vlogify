import SwiftUI

/// The pen every outline in the app is drawn with.
///
/// A drawn outline is not a stroked rectangle. Three things make a line read as
/// hand-drawn, and each is here on purpose:
/// - **Low-frequency wobble.** The line drifts off the ideal edge and back, two or three
///   slow swells per loop plus a faster tremor. Periodic, so it does not jump anywhere.
/// - **It does not close.** A hand drawing a loop ends a little off where it began, so
///   the offset drifts along the loop and the pen runs past its start (`overshoot`).
///   That small crossing is most of the effect.
/// - **Seeded by size.** The same button draws the same line every frame, and two buttons
///   of different sizes never share a line.
public struct PenShape: Shape {
    public enum Corner: Hashable, Sendable {
        case radius(CGFloat)
        case capsule
        case circle
    }

    public let corner: Corner
    public let seed: UInt64
    /// Peak distance the line strays from the ideal edge, in points.
    public let wobble: CGFloat
    /// Whether the pen runs on past where it started. Off for fills.
    public let overshoot: Bool

    public init(_ corner: Corner = .radius(Radius.card), seed: UInt64 = 0, wobble: CGFloat = Pen.wobble, overshoot: Bool = true) {
        self.corner = corner
        self.seed = seed
        self.wobble = wobble
        self.overshoot = overshoot
    }

    public func path(in rect: CGRect) -> Path {
        guard rect.width > 2, rect.height > 2 else { return Path(rect) }
        let inset = rect.insetBy(dx: wobble + 0.5, dy: wobble + 0.5)
        let outline = Outline(corner: corner, rect: inset)
        var random = SplitMix(seed: seed ^ Self.sizeHash(rect.size))
        let swell = Double(2 + Int(random.next() * 2))           // 2 or 3 slow swells
        let tremor = Double(5 + Int(random.next() * 3))          // 5..7 faster ones
        let phaseA = random.next() * 2 * .pi
        let phaseB = random.next() * 2 * .pi
        // Where on the loop the pen starts: somewhere along the top-left, like a hand.
        let start = 0.62 + random.next() * 0.1
        let drift = Double(wobble) * (0.9 + random.next() * 0.6)
        let run = overshoot ? 1.0 + 0.06 + random.next() * 0.05 : 1.0
        let count = max(28, Int(outline.length / 6))
        let steps = Int(Double(count) * run)

        var points: [CGPoint] = []
        points.reserveCapacity(steps + 1)
        for step in 0...steps {
            let u = Double(step) / Double(count)
            let (point, normal) = outline.point(at: (start + u).truncatingRemainder(dividingBy: 1))
            let offset = Double(wobble) * (0.65 * sin(2 * .pi * swell * u + phaseA) + 0.35 * sin(2 * .pi * tremor * u + phaseB))
                + (overshoot ? drift * u : 0)
            points.append(CGPoint(x: point.x + normal.dx * offset, y: point.y + normal.dy * offset))
        }
        return overshoot ? Ink.smooth(points) : Ink.smooth(points, closed: true)
    }

    static func sizeHash(_ size: CGSize) -> UInt64 {
        let w = UInt64(max(0, size.width.rounded()))
        let h = UInt64(max(0, size.height.rounded()))
        return (w &* 0x9E37_79B9_7F4A_7C15) ^ (h &* 0xC2B2_AE3D_27D4_EB4F)
    }
}

/// The ideal edge a pen line follows: a rounded rectangle walked clockwise from the
/// middle of the top edge, or an ellipse, parameterised by arc length.
struct Outline {
    enum Kind { case roundedRect(CGFloat), ellipse }
    let kind: Kind
    let rect: CGRect

    init(corner: PenShape.Corner, rect: CGRect) {
        self.rect = rect
        let limit = min(rect.width, rect.height) / 2
        switch corner {
        case .radius(let r): kind = .roundedRect(min(max(r, 0), limit))
        case .capsule: kind = .roundedRect(limit)
        case .circle: kind = .ellipse
        }
    }

    var length: Double {
        switch kind {
        case .ellipse:
            // Ramanujan.
            let a = Double(rect.width / 2), b = Double(rect.height / 2)
            return .pi * (3 * (a + b) - ((3 * a + b) * (a + 3 * b)).squareRoot())
        case .roundedRect(let r):
            return Double(2 * (rect.width - 2 * r) + 2 * (rect.height - 2 * r)) + 2 * .pi * Double(r)
        }
    }

    /// A point on the edge at fraction `t` of the way round, and its outward normal.
    func point(at t: Double) -> (CGPoint, CGVector) {
        switch kind {
        case .ellipse:
            let angle = -Double.pi / 2 + t * 2 * .pi
            let a = Double(rect.width / 2), b = Double(rect.height / 2)
            let p = CGPoint(x: rect.midX + CGFloat(cos(angle) * a), y: rect.midY + CGFloat(sin(angle) * b))
            let n = Self.unit(dx: cos(angle) * b, dy: sin(angle) * a)
            return (p, n)
        case .roundedRect(let r):
            return roundedPoint(at: t, radius: Double(r))
        }
    }

    private func roundedPoint(at t: Double, radius r: Double) -> (CGPoint, CGVector) {
        let x0 = Double(rect.minX), y0 = Double(rect.minY), x1 = Double(rect.maxX), y1 = Double(rect.maxY)
        let w = x1 - x0 - 2 * r, h = y1 - y0 - 2 * r
        let arc = Double.pi * r / 2
        let segments: [Double] = [w / 2, arc, h, arc, w, arc, h, arc, w / 2]
        var s = t * segments.reduce(0, +)
        for (index, length) in segments.enumerated() {
            if s <= length || index == segments.count - 1 {
                let f = length > 0 ? s / length : 0
                switch index {
                case 0: return (CGPoint(x: x0 + r + w / 2 + f * w / 2, y: y0), CGVector(dx: 0, dy: -1))
                case 1: return corner(cx: x1 - r, cy: y0 + r, r: r, from: -.pi / 2, f: f)
                case 2: return (CGPoint(x: x1, y: y0 + r + f * h), CGVector(dx: 1, dy: 0))
                case 3: return corner(cx: x1 - r, cy: y1 - r, r: r, from: 0, f: f)
                case 4: return (CGPoint(x: x1 - r - f * w, y: y1), CGVector(dx: 0, dy: 1))
                case 5: return corner(cx: x0 + r, cy: y1 - r, r: r, from: .pi / 2, f: f)
                case 6: return (CGPoint(x: x0, y: y1 - r - f * h), CGVector(dx: -1, dy: 0))
                case 7: return corner(cx: x0 + r, cy: y0 + r, r: r, from: .pi, f: f)
                default: return (CGPoint(x: x0 + r + f * w / 2, y: y0), CGVector(dx: 0, dy: -1))
                }
            }
            s -= length
        }
        return (CGPoint(x: x0 + r, y: y0), CGVector(dx: 0, dy: -1))
    }

    private func corner(cx: Double, cy: Double, r: Double, from: Double, f: Double) -> (CGPoint, CGVector) {
        let angle = from + f * .pi / 2
        return (CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r), CGVector(dx: cos(angle), dy: sin(angle)))
    }

    static func unit(dx: Double, dy: Double) -> CGVector {
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return CGVector(dx: 0, dy: -1) }
        return CGVector(dx: dx / length, dy: dy / length)
    }
}

/// Pen constants. One line weight for the whole app, like one pen.
public enum Pen {
    /// Outlines, doodles, icons.
    public static let line: CGFloat = 1.8
    /// The big drawings (onboarding) -- the same pen, pressed a little harder.
    public static let bold: CGFloat = 2.4
    /// How far an outline strays from its ideal edge.
    public static let wobble: CGFloat = 1.3
}

/// Strokes in a unit square, drawn into any rect: the renderer for doodles and marks.
///
/// Points are joined with quadratic curves through their midpoints, which turns a
/// finger's jagged polyline into a pen line without moving where it went. A one-point
/// stroke is a dot. The path runs stroke after stroke in the order they were drawn, so
/// `trim(from:to:)` redraws the drawing the way it was made.
public struct InkStrokes: Shape {
    public let strokes: [[CGPoint]]
    /// The part of the unit square to fit into the rect. Marks pass their ink bounds so
    /// a small doodle drawn in a corner still fills its avatar.
    public let box: CGRect
    public let padding: CGFloat

    public init(_ strokes: [[CGPoint]], box: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), padding: CGFloat = 0) {
        self.strokes = strokes
        self.box = box
        self.padding = padding
    }

    public func path(in rect: CGRect) -> Path {
        let area = rect.insetBy(dx: padding, dy: padding)
        guard box.width > 0, box.height > 0, area.width > 0, area.height > 0 else { return Path() }
        let scale = min(area.width / box.width, area.height / box.height)
        let origin = CGPoint(x: area.midX - box.width * scale / 2, y: area.midY - box.height * scale / 2)
        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + (p.x - box.minX) * scale, y: origin.y + (p.y - box.minY) * scale)
        }
        var path = Path()
        for stroke in strokes {
            let points = stroke.map(map)
            guard let first = points.first else { continue }
            if points.count == 1 {
                path.move(to: first)
                path.addLine(to: CGPoint(x: first.x + 0.01, y: first.y))
            } else {
                path.addPath(Ink.smooth(points))
            }
        }
        return path
    }
}

public enum Ink {
    /// Quadratic-through-midpoints smoothing. Open by default.
    public static func smooth(_ points: [CGPoint], closed: Bool = false) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        guard points.count > 2 else {
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
            return path
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        if closed {
            path.move(to: mid(points[points.count - 1], points[0]))
            for index in 0..<points.count {
                let next = points[(index + 1) % points.count]
                path.addQuadCurve(to: mid(points[index], next), control: points[index])
            }
            path.closeSubpath()
        } else {
            path.move(to: first)
            for index in 1..<(points.count - 1) {
                path.addQuadCurve(to: mid(points[index], points[index + 1]), control: points[index])
            }
            path.addLine(to: points[points.count - 1])
        }
        return path
    }

    public static func style(_ width: CGFloat = Pen.line) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}

/// A drawing that draws itself: the pen traces every stroke in order, once, on appear.
/// Reduce Motion gets the finished drawing.
public struct InkDrawing: View {
    private let strokes: [[CGPoint]]
    private let box: CGRect
    private let color: Color
    private let lineWidth: CGFloat
    private let duration: Double
    private let delay: Double
    private let animated: Bool
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ strokes: [[CGPoint]], box: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
                color: Color = .text, lineWidth: CGFloat = Pen.line,
                duration: Double = 1.2, delay: Double = 0, animated: Bool = true) {
        self.strokes = strokes
        self.box = box
        self.color = color
        self.lineWidth = lineWidth
        self.duration = duration
        self.delay = delay
        self.animated = animated
    }

    public var body: some View {
        InkStrokes(strokes, box: box, padding: lineWidth)
            .trim(from: 0, to: animated && !reduceMotion ? progress : 1)
            .stroke(color, style: Ink.style(lineWidth))
            .onAppear {
                guard animated, !reduceMotion else { return }
                progress = 0
                withAnimation(.easeInOut(duration: duration).delay(delay)) { progress = 1 }
            }
            .accessibilityHidden(true)
    }
}
