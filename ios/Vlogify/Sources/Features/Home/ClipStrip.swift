import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// Your clips along the foot of the page: this day's first, then earlier days as you
/// scroll. Tap to play.
struct ClipStrip: View {
    @Environment(AppState.self) private var state
    let day: DayKey
    let play: (Clip) -> Void
    @State private var items: [(day: DayKey, clip: Clip, member: Membership)] = []
    @State private var thumbnails: Thumbnails?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text("your clips").font(.vlogHandSmall).foregroundStyle(Color.textSoft)
                Spacer()
                Text(verbatim: "\(items.count)").font(.vlogCaption).foregroundStyle(Color.textSoft)
            }
            if items.isEmpty {
                Text("nothing yet. the camera is one tap away.")
                    .font(.vlogHandSmall).foregroundStyle(Color.textSoft)
                    .frame(height: 80)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.sm) {
                        ForEach(items, id: \.clip.id) { item in
                            VStack(alignment: .leading, spacing: Space.xxs) {
                                ClipTile(member: item.member, clip: item.clip, isMe: true, onPlay: play)
                                    .frame(width: 132)
                                Text(verbatim: item.day == day ? item.clip.slot.label : "\(state.clock.formatted(item.day)) · \(item.clip.slot.label)")
                                    .font(.vlogCaption).foregroundStyle(Color.textSoft)
                            }
                        }
                    }
                    .padding(.bottom, Sticker.drop)
                }
            }
        }
        .environment(thumbnails ?? Thumbnails(media: state.backend.media, local: state.cache))
        .onAppear { if thumbnails == nil { thumbnails = Thumbnails(media: state.backend.media, local: state.cache) } }
        .task(id: "\(day)-\(state.rooms.count)") { await load() }
        .accessibilityIdentifier("home.clips")
    }

    /// This day across every room, then the two previous days that have anything.
    private func load() async {
        guard let me = state.session?.userID else { return }
        var collected: [(DayKey, Clip, Membership)] = []
        var days = [day]
        for back in 1...2 {
            let earlier = DayClock.dayKey(for: DayClock.date(of: day, hour: 12, minute: 0, in: state.clock.timeZone)
                                             .addingTimeInterval(-86_400 * Double(back)), in: state.clock.timeZone)
            days.append(earlier)
        }
        for d in days {
            for room in state.rooms {
                guard let log = (try? await state.backend.clips.day(roomID: room.id, day: d)).map(state.withPending),
                      let mine = log.members.first(where: { $0.userID == me }) else { continue }
                for clip in log.clips where clip.memberID == me {
                    collected.append((d, clip, mine))
                }
            }
        }
        items = collected.sorted { ($0.0, $0.1.hour) > ($1.0, $1.1.hour) }.map { (day: $0.0, clip: $0.1, member: $0.2) }
    }
}
