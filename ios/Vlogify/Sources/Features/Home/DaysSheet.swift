import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// Every day you've had, as a calendar drawn on the page: a month at a time, each day
/// written in the hand. A day with clips is circled in pen, a day with notes has a dot
/// under it, today is inked in. Tap a day to turn home to that page.
struct DaysSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let pick: (DayKey) -> Void

    /// The first of the month on show.
    @State private var month: DayKey?
    @State private var clipDays: Set<DayKey> = []
    @State private var noteDays: Set<DayKey> = []

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = state.clock.timeZone
        calendar.locale = Locale.current
        return calendar
    }

    private var today: DayKey { state.clock.today }
    private var shown: DayKey { month ?? DayKey(year: today.year, month: today.month, day: 1) }
    private var isThisMonth: Bool { shown.year == today.year && shown.month == today.month }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                DoodleRound(doodle: .cross, label: "close") { dismiss() }
                    .accessibilityIdentifier("days.close")
                Spacer()
                HandwrittenText(text: String(localized: "your days", bundle: .app), font: .vlogTitle)
                Spacer()
                Color.clear.frame(width: Metrics.hitTarget + 4, height: 1)
            }
            monthLine
            grid
                .id(shown)
            HandwrittenText(text: summary, font: .vlogHandSmall, color: .textSoft, delay: 0.6)
                .id("summary-\(shown)")
            legend
            Spacer(minLength: 0)
        }
        .padding(Space.gutter)
        .background(Color.ground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationBackground(Color.ground)
        .presentationCornerRadius(Radius.frame)
        .task { await load() }
        .screen("screen.days")
    }

    // MARK: Pieces

    private var monthLine: some View {
        HStack(spacing: Space.sm) {
            arrow(.arrowLeft, label: "previous month", id: "days.previous") { turn(-1) }
            Text(verbatim: monthTitle)
                .font(.vlogShout)
                .foregroundStyle(Color.text)
                .frame(maxWidth: .infinity)
            arrow(.arrowRight, label: "next month", id: "days.next") { turn(1) }
                .opacity(isThisMonth ? 0.25 : 1)
                .disabled(isThisMonth)
        }
    }

    private func arrow(_ doodle: Doodle, label: LocalizedStringKey, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            DoodleSticker(doodle, scale: 0.9, lineWidth: 2)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(SquashButtonStyle())
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: Space.xs) {
            ForEach(Array(weekdayInitials.enumerated()), id: \.offset) { _, initial in
                Text(verbatim: initial)
                    .font(.vlogHandSmall)
                    .foregroundStyle(Color.textSoft)
                    .frame(height: 28)
            }
            ForEach(Array(cells.enumerated()), id: \.offset) { index, day in
                if let day {
                    DayCell(day: day, label: state.clock.formatted(day), isToday: day == today, hasClips: clipDays.contains(day),
                            hasNotes: noteDays.contains(day), isFuture: day > today,
                            delay: 0.1 + Double(index) * 0.015) {
                        Haptics.tap()
                        pick(day)
                        dismiss()
                    }
                } else {
                    Color.clear.frame(height: DayCell.height)
                }
            }
        }
        .writeIn(duration: 0.6)
    }

    private var legend: some View {
        HStack(spacing: Space.lg) {
            HStack(spacing: Space.xs) {
                PenShape(.circle, seed: 5, wobble: 0.6).stroke(Color.text, style: Ink.style(1.6))
                    .frame(width: 22, height: 22)
                Text("clips").font(.vlogHandSmall).foregroundStyle(Color.textSoft)
            }
            HStack(spacing: Space.xs) {
                Circle().fill(Color.text).frame(width: 5, height: 5)
                Text("notes").font(.vlogHandSmall).foregroundStyle(Color.textSoft)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Calendar maths

    private var monthTitle: String {
        firstOfMonth.formatted(Date.FormatStyle(timeZone: state.clock.timeZone).month(.wide).year()).lowercased()
    }

    private var firstOfMonth: Date {
        DayClock.date(of: shown, hour: 12, minute: 0, in: state.clock.timeZone)
    }

    /// Veryshort weekday symbols, starting on the reader's own first weekday.
    private var weekdayInitials: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols.map { $0.lowercased() }
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// Blanks before the 1st so it lands under its weekday, then every day of the month.
    private var cells: [DayKey?] {
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let lead = (weekday - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let days = (1...count).map { DayKey(year: shown.year, month: shown.month, day: $0) }
        return Array(repeating: nil, count: lead) + days
    }

    private var summary: String {
        let filmed = clipDays.filter { $0.year == shown.year && $0.month == shown.month }.count
        return String(localized: "\(filmed) days filmed this month.", bundle: .app)
    }

    private func turn(_ delta: Int) {
        guard let date = calendar.date(byAdding: .month, value: delta, to: firstOfMonth) else { return }
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let year = parts.year, let number = parts.month else { return }
        let next = DayKey(year: year, month: number, day: 1)
        guard next <= DayKey(year: today.year, month: today.month, day: 1) else { return }
        Haptics.tap()
        withAnimation(Motion.shift) { month = next }
    }

    /// Clip days come from every room's history on the backend; note days from this phone.
    /// A room whose history fails to load simply shows no circles -- the calendar is a way
    /// in, not a record.
    private func load() async {
        noteDays = state.notes.daysWithNotes()
        var days = Set<DayKey>()
        for room in state.rooms {
            if let history = try? await state.backend.clips.history(roomID: room.id) {
                days.formUnion(history)
            }
        }
        clipDays = days
    }
}

/// One day on the calendar: its number in the hand, circled in pen if it has clips, a dot
/// under it if it has notes, inked in if it is today. The circle draws itself.
private struct DayCell: View {
    static let height: CGFloat = 48

    let day: DayKey
    let label: String
    let isToday: Bool
    let hasClips: Bool
    let hasNotes: Bool
    let isFuture: Bool
    let delay: Double
    let open: () -> Void
    @State private var ink: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: open) {
            ZStack {
                if isToday {
                    PenShape(.circle, seed: UInt64(day.day), wobble: 0.8, overshoot: false)
                        .fill(Color.text)
                        .frame(width: 38, height: 38)
                } else if hasClips {
                    PenShape(.circle, seed: UInt64(day.day), wobble: 0.8)
                        .trim(from: 0, to: ink)
                        .stroke(Color.text, style: Ink.style(1.6))
                        .frame(width: 38, height: 38)
                }
                Text(verbatim: "\(day.day)")
                    .font(.vlogHand)
                    .foregroundStyle(isToday ? Color.card : Color.text)
                if hasNotes {
                    Circle().fill(Color.text)
                        .frame(width: 5, height: 5)
                        .offset(y: 22)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .contentShape(Rectangle())
            .opacity(isFuture ? 0.25 : 1)
        }
        .buttonStyle(SquashButtonStyle())
        .disabled(isFuture)
        .onAppear {
            guard !reduceMotion else { ink = 1; return }
            withAnimation(.easeInOut(duration: 0.45).delay(delay)) { ink = 1 }
        }
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityValue(Text(hasClips ? "clips" : hasNotes ? "notes" : ""))
        .accessibilityIdentifier("days.\(day)")
    }
}
