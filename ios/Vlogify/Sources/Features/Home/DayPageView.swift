import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// Home is a page in a notebook, and it draws itself in the way onboarding does: the date
/// is written, the clock traces itself at the real time with a line under it, then each
/// room is written in with a rule under it, then your own page, then your clips as
/// polaroids. That happens the first time the page appears in a launch and when you turn
/// to another day; coming back from the camera finds it already written.
struct DayPageView: View {
    @Environment(AppState.self) private var state
    @Binding var openRoom: Room?
    /// The day on show; nil is today. Home owns it so the calendar can turn the page too.
    @Binding var day: DayKey?
    @State private var playing: Clip?
    @State private var animated: Bool
    /// A fresh page each time the day changes, so it writes itself in again.
    @State private var pageID = UUID()
    @FocusState private var titleFocused: Bool

    /// Once per launch: the page writes itself in the first time it is seen.
    @MainActor private static var writtenThisLaunch = false

    init(openRoom: Binding<Room?>, day: Binding<DayKey?>) {
        _openRoom = openRoom
        _day = day
        _animated = State(initialValue: !Self.writtenThisLaunch && !LaunchArguments.isUITesting)
    }

    private var shownDay: DayKey { day ?? state.clock.today }
    private var scope: NotesStore.Scope { .day(shownDay) }
    private var isToday: Bool { shownDay == state.clock.today }

    /// When each part of the page starts drawing, so it arrives in the order a hand would
    /// make it.
    private enum Cue {
        static let date = 0.0
        static let clock = 0.3
        static func rooms(today: Bool) -> Double { today ? HourDrawing.finish(delay: clock) - 0.4 : 0.5 }
        static let perRoom = 0.35
    }

    var body: some View {
        ScrollViewReader { reader in
            page
                .onAppear {
                    #if DEBUG
                    if LaunchArguments.screen == "homeEnd" {
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            reader.scrollTo("page.clips", anchor: .bottom)
                        }
                    }
                    #endif
                }
        }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                dateLine
                if isToday {
                    HourDrawing(animated: animated, delay: Cue.clock)
                        .padding(.vertical, Space.xs)
                }
                if !state.rooms.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(state.rooms.enumerated()), id: \.element.id) { index, room in
                            RoomBlock(room: room, log: state.roomProgress[room.id], animated: animated,
                                      delay: Cue.rooms(today: isToday) + Double(index) * Cue.perRoom) { openRoom = room }
                        }
                    }
                }
                yourPage
                    .writeIn(delay: pageDelay, duration: 0.6, animated: animated)
                ClipStrip(day: shownDay, animated: animated) { playing = $0 }
                    .padding(.top, Space.sm)
                    .id("page.clips")
            }
            .id(pageID)
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await state.loadRooms() }
        // Turning to another day -- by the arrows or the calendar -- writes the new page in.
        .onChange(of: day) {
            animated = !LaunchArguments.isUITesting
            pageID = UUID()
        }
        .onAppear {
            Self.writtenThisLaunch = true
            seedFirstDayIfEmpty()
        }
        .fullScreenCover(item: $playing) { clip in ClipPlayerView(clip: clip) }
        .screen("home.page")
    }

    private var pageDelay: Double {
        Cue.rooms(today: isToday) + Double(state.rooms.count) * Cue.perRoom + 0.2
    }

    private var dateLine: some View {
        HStack(alignment: .center, spacing: Space.xs) {
            dayArrow(.arrowLeft, label: "previous day", id: "page.previous") { step(-1) }
            HandwrittenText(text: state.clock.formatted(shownDay).lowercased(), font: .vlogShout,
                            delay: Cue.date, animated: animated)
                .lineLimit(1)
                .background(alignment: .bottom) {
                    DrawnRule(seed: 11, delay: Cue.date + 0.35, animated: animated)
                        .offset(y: 8)
                }
            if !isToday {
                dayArrow(.arrowRight, label: "next day", id: "page.next") { step(1) }
            }
            Spacer()
        }
        .accessibilityElement(children: .contain)
    }

    private func dayArrow(_ doodle: Doodle, label: LocalizedStringKey, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            DoodleSticker(doodle, scale: 0.9, lineWidth: 2)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(SquashButtonStyle())
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }

    /// Your own writing for the day: a title you can type over, and blocks under it.
    private var yourPage: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            TextField("what happened today?", text: titleBinding, axis: .vertical)
                .font(.vlogHandTitle)
                .foregroundStyle(Color.text)
                .focused($titleFocused)
                .lineLimit(1...3)
                .accessibilityIdentifier("page.title")
            NotesBlockList(scope: scope, placeholder: "tap to write about today…")
        }
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

    /// The first page starts with one thing to do. Onboarding and the coach marks already
    /// explain the app, so the page itself stays yours. Once only.
    private func seedFirstDayIfEmpty() {
        guard isToday, !UserDefaults.standard.bool(forKey: "seededFirstPage"),
              !state.notes.hasContent(scope) else { return }
        UserDefaults.standard.set(true, forKey: "seededFirstPage")
        state.notes.update(scope) { page in
            page.blocks = [.init(kind: .todo, text: String(localized: "start my first room", bundle: .app))]
        }
    }
}
