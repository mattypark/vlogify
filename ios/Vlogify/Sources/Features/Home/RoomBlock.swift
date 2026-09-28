import SwiftUI
import VlogifyContract
import VlogifyDesign

/// A room, as a block on the page: a sticker card with the name, who is in it, today's
/// dots, and the next thing to do.
struct RoomBlock: View {
    @Environment(AppState.self) private var state
    let room: Room
    let log: DayLog?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Text(verbatim: room.name ?? (room.isSolo ? String(localized: "just me", bundle: .app) : String(localized: "untitled room", bundle: .app)))
                        .font(.vlogShout)
                        .foregroundStyle(Color.text)
                    Spacer()
                    if room.isSolo {
                        Text("only you").font(.vlogHandSmall).foregroundStyle(Color.textSoft)
                    } else {
                        HStack(spacing: -8) {
                            ForEach((log?.members ?? []).prefix(5)) { member in
                                AvatarDisc(profile: member.profile, size: 28)
                                    .background(Circle().fill(Color.card))
                            }
                        }
                    }
                }
                HourDots(log: log, userID: state.session?.userID, currentSlot: state.clock.currentSlot)
                HStack {
                    Text(verbatim: statusLine).font(.vlogHandSmall).foregroundStyle(Color.textSoft)
                    Spacer()
                    Image(systemName: "arrow.right").font(Font.system(size: 13, weight: .bold)).foregroundStyle(Color.text)
                }
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(StickerButtonStyle(fill: fill, radius: Radius.card))
        .stickerRoom()
        .accessibilityIdentifier("home.room.\(room.id)")
    }

    /// Paper. A room is its outline and its people.
    private var fill: Color { .card }

    private var statusLine: String {
        if room.isSolo {
            return String(localized: "\(log?.clips.count ?? 0) clips today", bundle: .app)
        }
        if state.hasPosted(in: room, slot: state.clock.currentSlot) {
            return String(localized: "got \(state.clock.currentSlot.label). next nudge in \(Clock.countdown(state.clock.secondsUntilPing(room: room.id)))", bundle: .app)
        }
        return String(localized: "\(state.clock.currentSlot.label) is open. your two seconds?", bundle: .app)
    }
}
