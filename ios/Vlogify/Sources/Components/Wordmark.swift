import SwiftUI
import VlogifyDesign

/// The logo: "vlogify", written by hand. Lowercase, always.
struct Wordmark: View {
    var onPaper = true
    var size: CGFloat = 34

    var body: some View {
        Text(verbatim: "vlogify")
            .font(Typography.handFont(size: size, relativeTo: .largeTitle))
            .foregroundStyle(onPaper ? Color.text : Color.chalk)
            .accessibilityLabel("vlogify")
    }
}
