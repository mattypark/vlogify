import SwiftUI
import VlogifyDesign

/// The big hour on the camera and on a tile. On the camera it turns in quarter turns,
/// however the person filming last left it (`CapturePreferences.stampTurn`).
///
/// Laid out in a fixed square *before* rotating, then centred -- rotating an
/// already-laid-out label leaves it visibly off-centre because the frame does not turn
/// with it.
struct HourStamp: View {
    let label: String
    /// Degrees clockwise: 0 upright, 270 tops facing 9 o'clock.
    var turn: Double = 0
    var size: CGFloat = 44
    var font: StampFont = .heavy

    static let box: CGFloat = 150

    var body: some View {
        Text(verbatim: label)
            .font(font.font(size: size))
            .foregroundStyle(Color.chalk)
            .shadow(color: Color.ink.opacity(0.55), radius: 6, y: 2)
            .fixedSize()
            .frame(width: Self.box, height: Self.box)
            .rotationEffect(.degrees(turn))
            .frame(width: Self.box, height: Self.box)
            .animation(.spring(duration: 0.4, bounce: 0.1), value: turn)
            .accessibilityLabel(Text(verbatim: label))
    }
}
