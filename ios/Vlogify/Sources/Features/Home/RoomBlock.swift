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
                    Text(verbatim: room.name ?? (room.isSolo ? String(localized: "just me", bundle: .app) : String(localized: "untitled log", bundle: .app)))
                        .font(.vlogShout)
                        .foregroundStyle(Color.text)
                    Spacer()
                    if room.isSolo {
                        Text("vlog").font(.vlogCaption).foregroundStyle(Color.textSoft)
                    } else {
                        HStack(spacing: -8) {
                            ForEach((log?.members ?? []).prefix(5)) { member in
                                AvatarDisc(profile: member.profile, size: 24)
                                    .overlay(Circle().stroke(Color.soot, lineWidth: 2))
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

    /// A stable playful colour per room, so two rooms never look the same.
    private var fill: Color {
        Color(Palette.playful(index: abs(room.id.hashValue % 7)).wash)
    }

    private var statusLine: String {
        if room.isSolo {
            return String(localized: "\(log?.clips.count ?? 0) clips today", bundle: .app)
        }
        if state.hasPosted(in: room, slot: state.clock.currentSlot) {
            return String(localized: "posted \(state.clock.currentSlot.label). next ping in \(Clock.countdown(state.clock.secondsUntilPing(room: room.id)))", bundle: .app)
        }
        return String(localized: "it's \(state.clock.currentSlot.label). add your clip.", bundle: .app)
    }
}
