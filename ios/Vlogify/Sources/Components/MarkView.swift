import SwiftUI
import VlogifyContract
import VlogifyDesign

extension Mark {
    /// The strokes as points for the renderer.
    var points: [[CGPoint]] {
        strokes.map { stroke in stroke.map { CGPoint(x: $0.x, y: $0.y) } }
    }

    /// The ink's own bounds, squared up and given a margin, so a small doodle drawn in a
    /// corner of the canvas still fills the space it is shown in.
    var fitBox: CGRect {
        let b = bounds
        let side = max(b.maxX - b.minX, b.maxY - b.minY) * 1.12
        let cx = (b.minX + b.maxX) / 2, cy = (b.minY + b.maxY) / 2
        return CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)
    }
}

/// A person, drawn: their mark, or their initials in the pen hand until they draw one.
struct MarkView: View {
    let mark: Mark?
    var name = ""
    var size: CGFloat = Metrics.avatar
    var animated = false
    var color: Color = .text

    var body: some View {
        Group {
            if let mark, !mark.isEmpty {
                InkDrawing(mark.points, box: mark.fitBox, color: color, lineWidth: lineWidth,
                           duration: 0.4 + Double(mark.pointCount) / 220, animated: animated)
            } else {
                Text(verbatim: String(name.prefix(2)).lowercased())
                    .font(Typography.handFont(size: size * 0.46))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: name))
    }

    /// Thin at avatar size, a real pen line at hero size.
    private var lineWidth: CGFloat {
        min(max(size / 26, 1.2), 3.2)
    }
}

/// Where a person's finger draws their mark: a drawn square on the page, the strokes
/// following the finger, undo and start-over. Points are stored in the unit square so
/// the mark means the same thing at any size.
struct MarkCanvas: View {
    @Binding var strokes: [[CGPoint]]
    @State private var current: [CGPoint] = []

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                InkStrokes(strokes + (current.isEmpty ? [] : [current]))
                    .stroke(Color.text, style: Ink.style(Pen.bold + 0.6))
                    .padding(Space.sm)
            }
            .frame(width: side, height: side)
            .background { PenShape(.radius(Radius.sheet)).stroke(Color.text, style: Ink.style()) }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let inner = side - Space.sm * 2
                        let point = CGPoint(x: (value.location.x - Space.sm) / inner,
                                            y: (value.location.y - Space.sm) / inner)
                        if let last = current.last,
                           hypot(point.x - last.x, point.y - last.y) * inner < 1.5 { return }
                        current.append(point)
                    }
                    .onEnded { _ in
                        guard !current.isEmpty else { return }
                        strokes.append(current)
                        current = []
                        Haptics.tap()
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(Text("drawing area"))
        .accessibilityHint(Text("draw your mark with one finger"))
        .accessibilityIdentifier("mark.canvas")
    }
}

/// The canvas with its handwritten instruction and its two tools. Used in onboarding and
/// from Profile to redraw.
struct MarkEditor: View {
    @Binding var strokes: [[CGPoint]]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .bottom, spacing: Space.xxs) {
                Text("draw")
                    .font(.vlogAnnotation)
                    .foregroundStyle(Color.text)
                DoodleSticker(.arrowDownRight, scale: 0.7)
                    .offset(y: 10)
            }
            .padding(.leading, Space.sm)
            .accessibilityHidden(true)
            MarkCanvas(strokes: $strokes)
            HStack {
                Button {
                    Haptics.tap()
                    _ = strokes.popLast()
                } label: {
                    DoodleSticker(.undo, scale: 1.1)
                        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                }
                .buttonStyle(SquashButtonStyle())
                .disabled(strokes.isEmpty)
                .opacity(strokes.isEmpty ? 0.3 : 1)
                .accessibilityLabel(Text("undo"))
                .accessibilityIdentifier("mark.undo")
                Spacer()
                Button {
                    Haptics.tap()
                    strokes = []
                } label: {
                    Text("start over")
                        .font(.vlogHandSmall)
                        .foregroundStyle(Color.textSoft)
                        .frame(height: Metrics.hitTarget)
                }
                .buttonStyle(.plain)
                .disabled(strokes.isEmpty)
                .opacity(strokes.isEmpty ? 0.3 : 1)
                .accessibilityIdentifier("mark.clear")
            }
        }
    }
}

extension Mark {
    init(canvas strokes: [[CGPoint]]) {
        self.init(strokes: strokes.map { stroke in stroke.map { MarkPoint(x: Double($0.x), y: Double($0.y)) } })
    }
}
