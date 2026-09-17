import SwiftUI
import VlogifyDesign

/// `camera | logs`. A sticker with the selected half filled.
struct SegmentToggle: View {
    @Binding var tab: AppState.Tab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            segment(.camera, "camera", fill: .blueLight)
            segment(.logs, "logs", fill: .sand)
        }
        .padding(Space.xxs)
        .sticker(fill: .card, radius: Radius.pill)
        .stickerRoom()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bar.segment")
    }

    private func segment(_ value: AppState.Tab, _ title: LocalizedStringKey, fill: Color) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.respecting(Motion.shift, reduceMotion: reduceMotion)) { tab = value }
        } label: {
            Text(title)
                .font(.vlogShout)
                .foregroundStyle(Color.text)
                .padding(.horizontal, Space.gutter)
                .frame(height: Metrics.hitTarget)
                .background {
                    if tab == value {
                        Capsule().fill(fill)
                            .overlay(Capsule().strokeBorder(Color.text, lineWidth: Sticker.lineThin))
                            .matchedGeometryEffect(id: "segment", in: namespace)
                    }
                }
        }
        .buttonStyle(SquashButtonStyle())
        .accessibilityIdentifier("bar.segment.\(value.rawValue)")
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }
}
