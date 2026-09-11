import SwiftUI
import VlogifyDesign

/// `camera | logs`. The pill in the middle of the bottom bar.
struct SegmentToggle: View {
    @Binding var tab: AppState.Tab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            segment(.camera, "camera")
            segment(.logs, "logs")
        }
        .padding(Space.xxs)
        .background(Color.surface, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bar.segment")
    }

    private func segment(_ value: AppState.Tab, _ title: LocalizedStringKey) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.respecting(Motion.shift, reduceMotion: reduceMotion)) { tab = value }
        } label: {
            Text(title)
                .font(.vlogLabel)
                .foregroundStyle(tab == value ? Color.chalk : Color.chalkSoft)
                .padding(.horizontal, Space.gutter)
                .frame(height: Metrics.hitTarget)
                .background {
                    if tab == value {
                        Capsule().fill(Color.surfaceRaised)
                            .matchedGeometryEffect(id: "segment", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bar.segment.\(value.rawValue)")
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }
}
