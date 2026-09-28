import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// Your clips along the foot of the page, as polaroids stuck in a notebook: this day's
/// first, then earlier days as you scroll. Tap to play.
struct ClipStrip: View {
    @Environment(AppState.self) private var state
    let day: DayKey
    var animated = false
    let play: (Clip) -> Void
    @State private var items: [(day: DayKey, clip: Clip, member: Membership)] = []
    @State private var thumbnails: Thumbnails?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("your clips").font(.vlogHand).foregroundStyle(Color.text)
                Spacer()
                Text(verbatim: "\(items.count)").font(.vlogHandSmall).foregroundStyle(Color.textSoft)
            }
            if items.isEmpty {
                Text("nothing yet. the camera is one tap away.")
                    .font(.vlogHandSmall).foregroundStyle(Color.textSoft)
                    .frame(height: 80)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.md) {
                        ForEach(Array(items.enumerated()), id: \.element.clip.id) { index, item in
                            Polaroid(clip: item.clip, caption: caption(for: item),
                                     tilt: index.isMultiple(of: 2) ? -2.5 : 2,
                                     drawIn: animated ? Double(min(index, 4)) * 0.12 : nil, play: play)
                        }
                    }
                    // Room for the tilt, so a corner never clips at the strip's edge.
                    .padding(.vertical, Space.sm)
                    .padding(.horizontal, Space.xxs)
                }
            }
        }
        .environment(thumbnails ?? Thumbnails(media: state.backend.media, local: state.cache))
        .onAppear { if thumbnails == nil { thumbnails = Thumbnails(media: state.backend.media, local: state.cache) } }
        .task(id: "\(day)-\(state.rooms.count)") { await load() }
        .accessibilityIdentifier("home.clips")
    }

    private func caption(for item: (day: DayKey, clip: Clip, member: Membership)) -> String {
        item.day == day ? item.clip.slot.label : "\(state.clock.formatted(item.day).lowercased()) · \(item.clip.slot.label)"
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

/// One clip as a polaroid: the first frame in a pen-drawn white frame, the hour written
/// on the bottom margin, stuck on slightly crooked.
private struct Polaroid: View {
    let clip: Clip
    let caption: String
    let tilt: Double
    let drawIn: Double?
    let play: (Clip) -> Void

    var body: some View {
        Button { play(clip) } label: {
            VStack(spacing: Space.xxs) {
                ClipThumbnail(clip: clip)
                    .frame(width: 108, height: 128)
                    .clipped()
                    .overlay { DoodleSticker(.play, scale: 1.1, lineWidth: 2.4, color: .chalk) }
                Text(verbatim: caption)
                    .font(.vlogHandSmall)
                    .foregroundStyle(Color.text)
                    .lineLimit(1)
                    .frame(width: 108)
            }
            .padding(.horizontal, Space.xs)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xxs)
        }
        .buttonStyle(StickerButtonStyle(fill: .card, radius: 3, drawIn: drawIn))
        .rotationEffect(.degrees(tilt))
        .accessibilityLabel(Text("your clip, \(caption)"))
    }
}
