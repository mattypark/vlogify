import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// Home is a page: a date, a title you can type over, blocks you tap to write, your rooms
/// as blocks, and your clips along the foot. It looks typed because it is -- the first
/// day's explainer is real blocks, editable and deletable.
struct DayPageView: View {
    @Environment(AppState.self) private var state
    @Binding var openRoom: Room?
    @State private var day: DayKey?
    @State private var playing: Clip?
    @FocusState private var titleFocused: Bool

    private var shownDay: DayKey { day ?? state.clock.today }
    private var scope: NotesStore.Scope { .day(shownDay) }
    private var isToday: Bool { shownDay == state.clock.today }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                dateLine
                titleField
                NotesBlockList(scope: scope, placeholder: "tap to write about today…")
                if !state.rooms.isEmpty {
                    VStack(spacing: Space.sm) {
                        ForEach(state.rooms) { room in
                            RoomBlock(room: room, log: state.roomProgress[room.id]) { openRoom = room }
                        }
                    }
                    .padding(.top, Space.xs)
                }
                ClipStrip(day: shownDay) { playing = $0 }
                    .padding(.top, Space.lg)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await state.loadRooms() }
        .onAppear { seedFirstDayIfEmpty() }
        .fullScreenCover(item: $playing) { clip in ClipPlayerView(clip: clip) }
        .screen("home.page")
    }

    private var dateLine: some View {
        HStack(spacing: Space.xs) {
            ChunkyRound(systemImage: "chevron.left", label: "previous day", size: 32) { step(-1) }
                .accessibilityIdentifier("page.previous")
            Text(verbatim: isToday ? String(localized: "today", bundle: .app) : state.clock.formatted(shownDay))
                .font(.vlogHandSmall)
                .foregroundStyle(Color.textSoft)
            ChunkyRound(systemImage: "chevron.right", label: "next day", size: 32) { step(1) }
                .opacity(isToday ? 0.3 : 1)
                .disabled(isToday)
                .accessibilityIdentifier("page.next")
            Spacer()
        }
    }

    private var titleField: some View {
        TextField("what happened today?", text: titleBinding, axis: .vertical)
            .font(.vlogHandTitle)
            .foregroundStyle(Color.text)
            .focused($titleFocused)
            .lineLimit(1...3)
            .accessibilityIdentifier("page.title")
    }

    private var titleBinding: Binding<String> {
        Binding(get: { state.notes.page(scope).title },
                set: { new in state.notes.update(scope) { $0.title = String(new.prefix(60)) } })
    }

    private func step(_ delta: Int) {
        let target = DayClock.dayKey(for: DayClock.date(of: shownDay, hour: 12, minute: 0, in: state.clock.timeZone)
                                        .addingTimeInterval(86_400 * Double(delta)), in: state.clock.timeZone)
        guard target <= state.clock.today else { return }
        Haptics.tap()
        withAnimation(Motion.shift) { day = target == state.clock.today ? nil : target }
    }

    /// The explainer, typed onto the very first page as real blocks. Once only.
    private func seedFirstDayIfEmpty() {
        guard isToday, !UserDefaults.standard.bool(forKey: "seededFirstPage"),
              !state.notes.hasContent(scope) else { return }
        UserDefaults.standard.set(true, forKey: "seededFirstPage")
        state.notes.update(scope) { page in
            page.blocks = [
                .init(kind: .text, text: String(localized: "this page is yours. nobody else sees what you write here.", bundle: .app)),
                .init(kind: .text, text: String(localized: "tap + to start a room with friends, or join one with a code.", bundle: .app)),
                .init(kind: .text, text: String(localized: "each hour your room gets a nudge at the same minute. film two seconds of whatever is in front of you.", bundle: .app)),
                .init(kind: .text, text: String(localized: "a room just for you has no limits. days turn over at 4 am.", bundle: .app)),
                .init(kind: .todo, text: String(localized: "start my first room", bundle: .app)),
            ]
        }
    }
}
