import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// The day as a row of twenty-four hand-drawn circles, like a habit tracker in a
/// notebook: an hour you filmed is coloured in, the hour it is now is circled harder,
/// an hour you missed is a light pencil ring, and the hours still to come are dots.
struct HourDots: View {
    let log: DayLog?
    let userID: UserID?
    let currentSlot: Slot

    private enum Mark { case filmed, now, missed, later }

    var body: some View {
        let marks = DayClock.slots(of: currentSlot.day).map(mark(for:))
        Canvas { context, size in
            let step = size.width / CGFloat(marks.count)
            let diameter = min(step - 2, size.height - 4)
            for (index, mark) in marks.enumerated() {
                let rect = CGRect(x: CGFloat(index) * step + (step - diameter) / 2,
                                  y: (size.height - diameter) / 2, width: diameter, height: diameter)
                let ring = PenShape(.circle, seed: UInt64(index + 1), wobble: 0.5).path(in: rect)
                switch mark {
                case .filmed:
                    // Coloured in. At this size a scribble reads as a letter, so it is solid ink.
                    let blob = PenShape(.circle, seed: UInt64(index + 1), wobble: 0.6, overshoot: false).path(in: rect)
                    context.fill(blob, with: .color(Color.text))
                case .now:
                    let loop = PenShape(.circle, seed: 24, wobble: 0.7).path(in: rect.insetBy(dx: -2, dy: -2))
                    context.stroke(loop, with: .color(Color.text), style: Ink.style(2.2))
                case .missed:
                    context.stroke(ring, with: .color(Color.textSoft), style: Ink.style(1))
                case .later:
                    let dot = CGRect(x: rect.midX - 1.2, y: rect.midY - 1.2, width: 2.4, height: 2.4)
                    context.fill(Path(ellipseIn: dot), with: .color(Color.textSoft.opacity(0.6)))
                }
            }
        }
        .frame(height: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(postedCount) of \(currentSlot.index + 1) hours posted"))
    }

    private var postedCount: Int {
        guard let log, let userID else { return 0 }
        return log.clips.filter { $0.memberID == userID }.count
    }

    private func mark(for slot: Slot) -> Mark {
        if let log, let userID, log.clip(from: userID, in: slot) != nil { return .filmed }
        if slot == currentSlot { return .now }
        return slot < currentSlot ? .missed : .later
    }
}
