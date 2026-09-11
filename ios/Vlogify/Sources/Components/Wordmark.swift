import SwiftUI
import VlogifyDesign

/// The logo. Mint on ink, soot on paper. Lowercase, always.
struct Wordmark: View {
    var onPaper = false
    var size: CGFloat = 30

    var body: some View {
        styled
            .foregroundStyle(Color.text)
            .accessibilityLabel("vlogify")
    }

    /// Built as a `Text` first so the tracking modifier, which only exists on `Text`,
    /// resolves before the view modifiers do.
    private var styled: Text {
        Text(verbatim: "vlogify")
            .font(Font.system(size: size, weight: .black, design: .rounded))
            .tracking(-1)
    }
}
