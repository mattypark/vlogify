import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// Twenty-four dots, one per hour of the app-day. Filled = you posted, orchid = the
/// current hour, dim = still to come. The whole day at a glance on a room card.
struct HourDots: View {
    let log: DayLog?
    let userID: UserID?
    let currentSlot: Slot

    var body: some View {
        HStack(spacing: 3) {
            ForEach(DayClock.slots(of: currentSlot.day), id: \.hour) { slot in
                Circle()
                    .fill(color(for: slot))
                    .frame(width: Metrics.hourDot, height: Metrics.hourDot)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(postedCount) of \(currentSlot.index + 1) hours posted"))
    }

    private var postedCount: Int {
        guard let log, let userID else { return 0 }
        return log.clips.filter { $0.memberID == userID }.count
    }

    private func color(for slot: Slot) -> Color {
        if let log, let userID, log.clip(from: userID, in: slot) != nil { return .text }
        if slot == currentSlot { return .action }
        if slot < currentSlot { return .cardRaised }
        return .hairline.opacity(0.6)
    }
}
