import SwiftUI

/// A smooth, random, organic outline — a drop of paint rather than a rounded box.
///
/// `points` radii are jittered from a seeded generator and joined with Catmull-Rom
/// splines converted to cubic Béziers, so the curve passes through every point and has no
/// corners. The same seed gives the same blob every launch, which is what lets a layout be
/// judged with placeholders in it.
public struct BlobShape: Shape {
    public let seed: UInt64
    public let points: Int
    /// 0 = a circle, 1 = wildly lumpy. 0.3–0.45 reads as paint.
    public let wobble: Double

    public init(seed: UInt64, points: Int = 7, wobble: Double = 0.38) {
        self.seed = seed
        self.points = max(4, points)
        self.wobble = min(max(wobble, 0), 1)
    }

    public init(seedString: String, points: Int = 7, wobble: Double = 0.38) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seedString.utf8 { hash ^= UInt64(byte); hash = hash &* 0x0000_0100_0000_01b3 }
        self.init(seed: hash, points: points, wobble: wobble)
    }

    public func path(in rect: CGRect) -> Path {
        let anchors = Self.anchors(seed: seed, points: points, wobble: wobble, in: rect)
        var path = Path()
        guard anchors.count >= 3 else { return path }
        path.move(to: anchors[0])
        let n = anchors.count
        for i in 0..<n {
            let p0 = anchors[(i - 1 + n) % n]
            let p1 = anchors[i]
            let p2 = anchors[(i + 1) % n]
            let p3 = anchors[(i + 2) % n]
            // Catmull-Rom → cubic Bézier, tension 0.5.
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    /// The jittered polar points, inset so the curve never leaves the rect.
    static func anchors(seed: UInt64, points: Int, wobble: Double, in rect: CGRect) -> [CGPoint] {
        var generator = SplitMix(seed: seed)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2, ry = rect.height / 2
        var result: [CGPoint] = []
        for index in 0..<points {
            // Angle jitter keeps lobes uneven; radius jitter makes them lumps.
            let baseAngle = Double(index) / Double(points) * 2 * .pi
            let angle = baseAngle + (generator.next() - 0.5) * (2 * .pi / Double(points)) * 0.6
            let radius = 1 - wobble * generator.next()
            result.append(CGPoint(x: center.x + CGFloat(cos(angle) * radius) * rx * 0.96,
                                  y: center.y + CGFloat(sin(angle) * radius) * ry * 0.96))
        }
        return result
    }
}

/// A blob painted rather than filled: a soft radial fade, a second offset lobe for the wet
/// edge, and a faint darker rim. Reads as a brush mark at any size.
public struct PaintBlob: View {
    let color: Color
    let seed: String

    public init(color: Color, seed: String) {
        self.color = color
        self.seed = seed
    }

    public var body: some View {
        ZStack {
            BlobShape(seedString: seed + "-wet", points: 6, wobble: 0.42)
                .fill(color.opacity(0.35))
                .offset(x: 6, y: 5)
                .blur(radius: 1.5)
            BlobShape(seedString: seed)
                .fill(RadialGradient(colors: [color, color.opacity(0.55)],
                                     center: UnitPoint(x: 0.42, y: 0.38), startRadius: 0, endRadius: 120))
            BlobShape(seedString: seed)
                .stroke(color.opacity(0.7), lineWidth: 1.5)
                .blur(radius: 0.8)
        }
    }
}

/// SplitMix64, 0..<1 doubles. Deterministic so shapes do not reshuffle every frame.
struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
}
