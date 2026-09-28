import SwiftUI
import VlogifyDesign

/// Text that arrives the way it would be written: one line after another, each revealed
/// left to right as if the pen were moving across it. Used where a page introduces itself
/// (onboarding), next to drawings that trace themselves in the same way.
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

    /// When the last line finishes: what a button waiting for the text should wait for.
    static func finish(of text: String, delay: Double, perLine: Double = 0.45) -> Double {
        delay + Double(text.components(separatedBy: "\n").count) * perLine
    }

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        VStack(alignment: alignment, spacing: 6) {
            ForEach(lines.indices, id: \.self) { index in
                WrittenLine(text: lines[index], font: font, color: color,
                            start: delay + Double(index) * perLine, duration: perLine)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text.replacingOccurrences(of: "\n", with: " ")))
    }
}

private struct WrittenLine: View {
    let text: String
    let font: Font
    let color: Color
    let start: Double
    let duration: Double
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: text)
            .font(font)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle().frame(width: proxy.size.width * progress)
                }
            }
            .onAppear {
                guard !reduceMotion else { progress = 1; return }
                withAnimation(.easeOut(duration: duration).delay(start)) { progress = 1 }
            }
    }
}
