import SwiftUI
import VlogifyDesign

/// Text that arrives the way it would be written: one line after another, each revealed
/// left to right as if the pen were moving across it. Used where a page introduces itself
/// (onboarding, home), next to drawings that trace themselves in the same way.
///
/// The whole text is one accessibility element from the start, and Reduce Motion shows it
/// finished.
struct HandwrittenText: View {
    let text: String
    var font: Font = .vlogBody
    var color: Color = .text
    var alignment: HorizontalAlignment = .leading
    /// When the first line starts.
    var delay: Double = 0
    /// How long each line takes to write, and so the gap before the next one starts.
    var perLine: Double = 0.45
    /// Off shows the text already written, for a page that has drawn itself in before.
    var animated = true

    /// When the last line finishes: what a button waiting for the text should wait for.
    static func finish(of text: String, delay: Double, perLine: Double = 0.45) -> Double {
        delay + Double(text.components(separatedBy: "\n").count) * perLine
    }

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        VStack(alignment: alignment, spacing: 6) {
            ForEach(lines.indices, id: \.self) { index in
                Text(verbatim: lines[index])
                    .font(font)
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
                    .writeIn(delay: delay + Double(index) * perLine, duration: perLine, animated: animated)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text.replacingOccurrences(of: "\n", with: " ")))
    }
}

/// Reveals any view left to right, the way a line of writing arrives: text, a row of
/// drawn hour circles, a row of marks.
private struct WriteIn: ViewModifier {
    let delay: Double
    let duration: Double
    let animated: Bool
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle().frame(width: proxy.size.width * progress)
                }
            }
            .onAppear {
                guard animated, !reduceMotion else { progress = 1; return }
                withAnimation(.easeOut(duration: duration).delay(delay)) { progress = 1 }
            }
    }
}

extension View {
    func writeIn(delay: Double = 0, duration: Double = 0.45, animated: Bool = true) -> some View {
        modifier(WriteIn(delay: delay, duration: duration, animated: animated))
    }
}
