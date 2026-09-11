import SwiftUI
import VlogifyDesign

/// The big hour on the camera and on a tile. On the camera it reads along the long
/// edge of the phone: turned sideways, the numerals turn with the horizon.
struct HourStamp: View {
    let label: String
    var rotated = false
    var size: CGFloat = 44

    var body: some View {
        Text(verbatim: label)
            .font(Font.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.paper)
            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
            .rotationEffect(.degrees(rotated ? -90 : 0))
            .animation(.easeInOut(duration: 0.25), value: rotated)
            .accessibilityLabel(Text(verbatim: label))
    }
}
