import SwiftUI
import VlogifyContract
import VlogifyDesign

/// The big drawing on today's page, the way each onboarding page has one: the same
/// clock, its hands at the real time, and one written line saying what the hour wants.
/// Tapping it opens the camera.
struct HourDrawing: View {
    @Environment(AppState.self) private var state
    var animated = false
    var delay: Double = 0

    static let scale: CGFloat = 1.05
    /// When the written line starts, after the clock has mostly drawn.
    static let lineDelay = 1.0

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.shift) { state.tab = .camera }
        } label: {
            VStack(spacing: Space.md) {
                TimelineView(.everyMinute) { _ in
                    let (hour, minute) = time
                    InkDrawing(Doodle.clock(hour: hour, minute: minute), box: Doodle.clock.box,
                               lineWidth: Pen.bold, duration: 1.3, delay: delay, animated: animated)
                        .frame(width: Doodle.clock.size.width * Self.scale, height: Doodle.clock.size.height * Self.scale)
                }
                HandwrittenText(text: line, font: .vlogBody, alignment: .center,
                                delay: delay + Self.lineDelay, animated: animated)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(InkPressStyle())
        .accessibilityHint(Text("opens the camera"))
        .accessibilityIdentifier("home.hour")
    }

    /// When the line finishes writing, for whatever waits on the drawing.
    static func finish(delay: Double) -> Double { delay + lineDelay + 2 * 0.45 }

    private var time: (Int, Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = state.clock.timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: state.clock.now)
        return (parts.hour ?? 0, parts.minute ?? 0)
    }

    /// "7 pm", in the reader's own clock style.
    private var hourText: String {
        var style = Date.FormatStyle.dateTime.hour()
        style.timeZone = state.clock.timeZone
        return state.clock.now.formatted(style).lowercased()
    }

    private var line: String {
        let slot = state.clock.currentSlot
        let rooms = state.rooms
        if !rooms.isEmpty, rooms.allSatisfy({ state.hasPosted(in: $0, slot: slot) }) {
            return String(localized: "got \(hourText).\nsee you next hour.", bundle: .app)
        }
        return String(localized: "it's \(hourText).\ntwo seconds?", bundle: .app)
    }
}
