import SwiftUI
import VlogifyDesign

/// The things the first-visit tour points at, found where they are actually drawn.
enum TourTarget: Hashable, CaseIterable {
    case record, days, rooms
}

struct TourAnchorKey: PreferenceKey {
    static let defaultValue: [TourTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TourTarget: Anchor<CGRect>], nextValue: () -> [TourTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks this view as something the tour can point at.
    func tourAnchor(_ target: TourTarget) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [target: $0] }
    }
}

/// The first visit to home explains the bar the way a note in a margin would. The page
/// dims, the button being talked about stays lit with a red pen circle drawn round it,
/// and a handwritten line fades in above it with a drawn arrow.
///
/// A: one thing at a time -- the record button, then where your days are kept, then
/// rooms -- a tap for the next. B: all three, fading in one after another; one tap closes.
struct CoachMarks: View {
    static let seenKey = "tourSeen"
    /// The older all-at-once tips. Someone who saw those has used the app before.
    static let legacySeenKey = "coachMarksSeen"

    let frames: [TourTarget: CGRect]
    let variant: DesignVariant
    let dismiss: () -> Void

    @State private var step = 0

    private static let order: [TourTarget] = [.record, .days, .rooms]
    private static let cascadeGap = 0.9

    private var shown: [TourTarget] {
        let visible = Self.order.filter { frames[$0] != nil }
        guard variant == .a else { return visible }
        return visible.indices.contains(step) ? [visible[step]] : []
    }

    private var stepCount: Int { Self.order.filter { frames[$0] != nil }.count }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                dimmer(in: proxy.size)
                ForEach(Array(shown.enumerated()), id: \.element) { index, target in
                    if let frame = frames[target] {
                        TourNote(text: Self.line(for: target),
                                 target: frame,
                                 bounds: proxy.size,
                                 lift: lift(for: target),
                                 width: width(for: target),
                                 delay: variant == .a ? 0.15 : Double(index) * Self.cascadeGap)
                    }
                }
                footer(in: proxy.size)
            }
            // Re-made per step, so each note fades in fresh rather than morphing.
            .id(variant == .a ? step : 0)
            .transition(.opacity)
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityIdentifier("coach.marks")
    }

    // MARK: Pieces

    /// The page behind, dimmed, with a hole round each button being talked about. Drawn
    /// well past the edges so the safe areas dim too.
    private func dimmer(in size: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(x: -400, y: -400, width: size.width + 800, height: size.height + 800))
            for target in shown {
                if let frame = frames[target] { path.addEllipse(in: frame.insetBy(dx: -10, dy: -10)) }
            }
        }
        .fill(Color.ground.opacity(0.97), style: FillStyle(eoFill: true))
    }

    private func footer(in size: CGSize) -> some View {
        FadeIn(delay: variant == .a ? 0.6 : Double(stepCount) * Self.cascadeGap) {
            VStack(spacing: Space.xxs) {
                if variant == .a, stepCount > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<stepCount, id: \.self) { index in
                            Circle()
                                .fill(index == step ? Color.text : Color.hairline)
                                .frame(width: 7, height: 7)
                        }
                    }
                }
                Text(variant == .a && step < stepCount - 1 ? "tap for the next one" : "tap anywhere to start")
                    .font(.vlogHandSmall)
                    .foregroundStyle(Color.textSoft)
            }
        }
        .position(x: size.width / 2, y: size.height * 0.3)
    }

    // MARK: Layout

    /// How far above its button a note sits. B stacks the middle one higher so the three
    /// never overlap.
    private func lift(for target: TourTarget) -> CGFloat {
        guard variant == .b else { return 90 }
        return target == .record ? 210 : 90
    }

    private func width(for target: TourTarget) -> CGFloat {
        variant == .b && target != .record ? 160 : 260
    }

    static func line(for target: TourTarget) -> LocalizedStringKey {
        switch target {
        case .record: return "this is the record button.\ntap it to film."
        case .days: return "every day you film\nis kept here."
        case .rooms: return "rooms live here.\nstart one, or join friends."
        }
    }

    private var accessibilityText: String {
        String(localized: "tips: the record button is in the middle, your days are kept on the left, rooms are on the right. tap to close.", bundle: .app)
    }

    private func advance() {
        guard variant == .a, step < stepCount - 1 else { return dismiss() }
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.35)) { step += 1 }
    }
}

/// One handwritten line above a button, a pen arrow down to it, and a red circle drawn
/// round it. The words fade up; the arrow and circle draw themselves after.
private struct TourNote: View {
    let text: LocalizedStringKey
    let target: CGRect
    let bounds: CGSize
    let lift: CGFloat
    let width: CGFloat
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    private var noteCenterX: CGFloat {
        let half = width / 2 + Space.gutter
        return min(max(target.midX, half), bounds.width - half)
    }

    private var noteBottom: CGFloat { target.minY - lift }

    private var alignment: TextAlignment {
        if noteCenterX > target.midX + 20 { return .leading }
        if noteCenterX < target.midX - 20 { return .trailing }
        return .center
    }

    var body: some View {
        ZStack {
            FadeIn(delay: delay) {
                Text(text)
                    .font(.vlogHand)
                    .foregroundStyle(Color.text)
                    .multilineTextAlignment(alignment)
                    .frame(width: width, alignment: frameAlignment)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: width)
            .position(x: noteCenterX, y: noteBottom - 30)

            arrow
                .trim(from: 0, to: drawn)
                .stroke(Color.text, style: Ink.style(2))

            PenShape(.circle, seed: 7, wobble: 1.6)
                .trim(from: 0, to: drawn)
                .stroke(Color.recording, style: Ink.style(2.6))
                .frame(width: target.width + 20, height: target.height + 20)
                .position(x: target.midX, y: target.midY)
        }
        .onAppear {
            let draw = Animation.easeOut(duration: 0.6).delay(delay + 0.35)
            withAnimation(Motion.respecting(draw, reduceMotion: reduceMotion)) { drawn = 1 }
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading: return .leading
        case .trailing: return .trailing
        default: return .center
        }
    }

    /// From under the words down to just above the circle, with a little hand-drawn bow
    /// and a two-stroke head.
    private var arrow: Path {
        Path { path in
            let start = CGPoint(x: noteCenterX + (target.midX - noteCenterX) * 0.35, y: noteBottom + 4)
            let end = CGPoint(x: target.midX, y: target.minY - 16)
            let bow = CGPoint(x: (start.x + end.x) / 2 + 14, y: (start.y + end.y) / 2)
            path.move(to: start)
            path.addQuadCurve(to: end, control: bow)
            path.move(to: CGPoint(x: end.x - 7, y: end.y - 9))
            path.addLine(to: end)
            path.addLine(to: CGPoint(x: end.x + 8, y: end.y - 8))
        }
    }
}

/// Fades and lifts its content in once, after a delay. Reduce Motion shows it at once.
private struct FadeIn<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 10)
            .onAppear {
                if reduceMotion { visible = true; return }
                withAnimation(.easeOut(duration: 0.6).delay(delay)) { visible = true }
            }
    }
}
