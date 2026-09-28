import SwiftUI
import VlogifyDesign

/// The big hour on the camera and on a tile. On the camera it reads along the long
/// edge of the phone: turned sideways, the numerals turn with the horizon.
///
/// Laid out in a fixed square *before* rotating, then centred -- rotating an
/// already-laid-out label leaves it visibly off-centre because the frame does not turn
/// with it.
struct HourStamp: View {
    let label: String
    var rotated = false
    var size: CGFloat = 44
    var font: StampFont = .hand

    static let box: CGFloat = 150

    var body: some View {
        Text(verbatim: label)
            .font(font.font(size: size))
            .foregroundStyle(Color.chalk)
            .shadow(color: Color.ink.opacity(0.55), radius: 6, y: 2)
            .fixedSize()
            .frame(width: Self.box, height: Self.box)
            .rotationEffect(.degrees(rotated ? -90 : 0))
            .frame(width: Self.box, height: Self.box)
            .animation(.easeInOut(duration: 0.25), value: rotated)
            .accessibilityLabel(Text(verbatim: label))
    }
}
