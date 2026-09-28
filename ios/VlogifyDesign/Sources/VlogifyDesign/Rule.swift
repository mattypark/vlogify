import SwiftUI

/// A line ruled by hand across a page: level on average, drifting a little off and back,
/// starting and stopping a hair short of either edge. Seeded by size like `PenShape`, so
/// a rule draws the same way every frame.
public struct PenLine: Shape {
    public let seed: UInt64
    public let wobble: CGFloat

    public init(seed: UInt64 = 0, wobble: CGFloat = Pen.wobble) {
        self.seed = seed
        self.wobble = wobble
    }

    public func path(in rect: CGRect) -> Path {
        guard rect.width > 2 else { return Path() }
        var random = SplitMix(seed: seed ^ PenShape.sizeHash(rect.size))
        let lead = Double(rect.width) * (0.004 + random.next() * 0.015)
        let tail = Double(rect.width) * (0.01 + random.next() * 0.035)
        // The whole line tilts a point or two, the way a hand never rules quite level.
        let tilt = (random.next() - 0.5) * Double(wobble) * 1.6
        let swell = 1.4 + random.next()
        let phase = random.next() * 2 * .pi
        let count = max(12, Int(rect.width / 8))
        let span = Double(rect.width) - lead - tail
        let points = (0...count).map { step -> CGPoint in
            let u = Double(step) / Double(count)
            let y = Double(rect.midY) + tilt * (u - 0.5) + Double(wobble) * 0.6 * sin(2 * .pi * swell * u + phase)
            return CGPoint(x: Double(rect.minX) + lead + span * u, y: y)
        }
        return Ink.smooth(points)
    }
}

/// A ruled line that can rule itself in, left to right. Reduce Motion gets the finished line.
public struct DrawnRule: View {
    private let color: Color
    private let lineWidth: CGFloat
    private let seed: UInt64
    private let delay: Double
    private let animated: Bool
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(color: Color = .text, lineWidth: CGFloat = Pen.line, seed: UInt64 = 0,
                delay: Double = 0, animated: Bool = false) {
        self.color = color
        self.lineWidth = lineWidth
        self.seed = seed
        self.delay = delay
        self.animated = animated
    }

    public var body: some View {
        PenLine(seed: seed)
            .trim(from: 0, to: animated && !reduceMotion ? progress : 1)
            .stroke(color, style: Ink.style(lineWidth))
            .frame(height: lineWidth + Pen.wobble * 4)
            .onAppear {
                guard animated, !reduceMotion else { return }
                progress = 0
                withAnimation(.easeInOut(duration: 0.5).delay(delay)) { progress = 1 }
            }
            .accessibilityHidden(true)
    }
}
