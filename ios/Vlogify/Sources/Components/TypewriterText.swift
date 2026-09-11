import SwiftUI
import VlogifyDesign

/// Monospace text that types itself in. Used on exactly one screen.
struct TypewriterText: View {
    let text: String
    var bold = false
    var color: Color = .chalkSoft
    var speed: Double = 0.018
    var onDone: (() -> Void)? = nil

    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: String(text.prefix(shown)))
            .font(bold ? .vlogMonoBold : .vlogMono)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: text) {
                // Reduce Motion, and the UI walker, both get the whole line at once.
                if reduceMotion || LaunchArguments.isUITesting {
                    shown = text.count
                    onDone?()
                    return
                }
                shown = 0
                for index in 1...max(1, text.count) {
                    try? await Task.sleep(for: .seconds(speed))
                    shown = index
                }
                onDone?()
            }
            .accessibilityLabel(Text(verbatim: text))
    }
}
