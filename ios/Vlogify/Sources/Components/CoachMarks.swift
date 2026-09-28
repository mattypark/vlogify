import SwiftUI
import VlogifyDesign

/// The first visit to home explains itself the way a note in a margin would: a few
/// handwritten words, each with a drawn arrow at the thing it means. One tap anywhere
/// and it is gone for good.
struct CoachMarks: View {
    static let seenKey = "coachMarksSeen"
    let dismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ground.opacity(0.9)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Text("tap anywhere")
                    .font(.vlogHandSmall)
                    .foregroundStyle(Color.textSoft)
                    .frame(maxHeight: .infinity, alignment: .center)
                HStack(alignment: .bottom) {
                    note("your day\nlives here", arrow: .arrowDown, delay: 0.1)
                        .frame(width: 112, alignment: .center)
                    Spacer()
                    note("tap to film", arrow: .arrowDown, delay: 0.5)
                    Spacer()
                    note("start a\nroom", arrow: .arrowDown, delay: 0.9)
                        .frame(width: 112, alignment: .center)
                }
                .padding(.horizontal, Space.sm)
                // Clears the bar so each arrow lands just above its button.
                .padding(.bottom, 84)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("tips: your day lives on the left, the camera is in the middle, start a room on the right. tap to close."))
        .accessibilityIdentifier("coach.marks")
    }

    private func note(_ text: LocalizedStringKey, arrow: Doodle, delay: Double) -> some View {
        VStack(spacing: Space.xxs) {
            Text(text)
                .font(.vlogHand)
                .foregroundStyle(Color.text)
                .multilineTextAlignment(.center)
                .fixedSize()
            DoodleSticker(arrow, scale: 0.9, animated: true, lineWidth: 2, delay: delay)
        }
    }
}
