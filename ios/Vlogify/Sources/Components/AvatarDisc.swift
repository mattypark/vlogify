import SwiftUI
import VlogifyContract
import VlogifyDesign

/// A person: their drawn mark inside a pen circle. No photos -- the clips are the faces,
/// and the mark is how you tell whose clip is whose.
struct AvatarDisc: View {
    let profile: Profile
    var size: CGFloat = Metrics.avatar

    var body: some View {
        MarkView(mark: profile.mark, name: profile.displayName, size: size * 0.74)
            .frame(width: size, height: size)
            .background { PenShape(.circle, wobble: max(0.6, size / 40)).stroke(Color.text, style: Ink.style(size > 60 ? Pen.line : 1.3)) }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: profile.displayName))
    }
}
