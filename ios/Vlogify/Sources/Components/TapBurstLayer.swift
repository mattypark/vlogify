import SwiftUI
import VlogifyDesign

/// A circle pops and stripes fly out wherever you tap. Random colour every time.
///
/// Sits over the onboarding screens only. `simultaneousGesture` so the buttons under it
/// still get the tap; the burst is a garnish, never a gate. Several may overlap. Reduce
/// Motion gets a single soft circle and no stripes.
struct TapBurstLayer: ViewModifier {
    @State private var bursts: [Burst] = []
    @State private var pulses = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Burst: Identifiable {
        let id = UUID()
        let point: CGPoint
        let color: Color
        let born: Date
        let spin: Double
        let stripes: Int
    }

    static let life: TimeInterval = 0.62

    func body(content: Content) -> some View {
        content
            .overlay {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: bursts.isEmpty)) { timeline in
                    Canvas { context, _ in
                        let now = timeline.date
                        for burst in bursts {
                            let t = min(1, now.timeIntervalSince(burst.born) / Self.life)
                            draw(burst, at: t, in: &context)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .accessibilityIdentifier("burst.layer")
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard value.translation.width.magnitude < 8, value.translation.height.magnitude < 8 else { return }
                        add(at: value.location)
                    }
            )
            .sensoryFeedback(.selection, trigger: pulses)
    }

    private func add(at point: CGPoint) {
        // Ink, always: a burst is a pen flick on the page, not confetti.
        bursts.append(Burst(point: point, color: .fog, born: Date(),
                            spin: .random(in: 0..<360), stripes: reduceMotion ? 0 : Int.random(in: 8...10)))
        pulses += 1
        // Prune well after the last one has faded; the timeline pauses when empty.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.life + 0.1))
            bursts.removeAll { Date().timeIntervalSince($0.born) > Self.life }
        }
    }

    /// The circle overshoots (1.18 at t≈0.3) then settles; stripes launch staggered,
    /// stretch outward, thin, and fade. Everything is a function of t so it is
    /// frame-rate independent.
    private func draw(_ burst: Burst, at t: Double, in context: inout GraphicsContext) {
        let pop = t < 0.3 ? (t / 0.3) * 1.18 : 1.18 - (t - 0.3) / 0.7 * 0.18
        let radius = 18 * pop
        let fade = t < 0.6 ? 1 : 1 - (t - 0.6) / 0.4
        var circle = Path()
        circle.addEllipse(in: CGRect(x: burst.point.x - radius, y: burst.point.y - radius,
                                     width: radius * 2, height: radius * 2))
        context.fill(circle, with: .color(burst.color.opacity(0.9 * fade)))
        context.stroke(circle, with: .color(Color.text.opacity(fade)), lineWidth: 3)

        guard burst.stripes > 0 else { return }
        for index in 0..<burst.stripes {
            let stagger = Double(index % 3) * 0.05
            let s = max(0, min(1, (t - stagger) / (1 - stagger)))
            guard s > 0 else { continue }
            let angle = (burst.spin + Double(index) * 360 / Double(burst.stripes)) * .pi / 180
            let travel = 26 + 58 * (1 - pow(1 - s, 3))           // ease-out flight
            let length = 22 * (1 - s) + 6                        // shortens as it flies
            let width = 7 * (1 - s) + 2
            let start = CGPoint(x: burst.point.x + cos(angle) * travel, y: burst.point.y + sin(angle) * travel)
            let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
            var stripe = Path()
            stripe.move(to: start)
            stripe.addLine(to: end)
            context.stroke(stripe, with: .color(burst.color.opacity((1 - s) * 0.95)),
                           style: StrokeStyle(lineWidth: width, lineCap: .round))
            context.stroke(stripe, with: .color(Color.text.opacity((1 - s) * 0.5)),
                           style: StrokeStyle(lineWidth: width + 2, lineCap: .round))
        }
    }
}

extension View {
    func tapBursts() -> some View { modifier(TapBurstLayer()) }
}
