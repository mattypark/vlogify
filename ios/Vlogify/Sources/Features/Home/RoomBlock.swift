import SwiftUI
import VlogifyContract
import VlogifyDesign

/// A room, as an entry in the notebook: its name written large, who is in it, today's
/// hours as a row of drawn circles, the next thing to do, and a ruled line under it all.
/// No box -- a page doesn't put its lines in boxes. It can write itself in, in that order.
struct RoomBlock: View {
    @Environment(AppState.self) private var state
    let room: Room
    let log: DayLog?
    var animated = false
    var delay: Double = 0
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .center, spacing: Space.sm) {
                    HandwrittenText(text: name, font: .vlogTitle, delay: delay, animated: animated)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: Space.xs)
                    people
                        .writeIn(delay: delay + 0.3, duration: 0.3, animated: animated)
                }
                HourDots(log: log, userID: state.session?.userID, currentSlot: state.clock.currentSlot)
                    .writeIn(delay: delay + 0.35, duration: 0.6, animated: animated)
                HStack(alignment: .center) {
                    HandwrittenText(text: statusLine, font: .vlogHandSmall, color: .textSoft,
                                    delay: delay + 0.6, animated: animated)
                    Spacer(minLength: Space.xs)
                    DoodleSticker(.arrowRight, scale: 0.8, animated: animated, lineWidth: 2, delay: delay + 0.8)
                }
            }
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(InkPressStyle())
        .overlay(alignment: .bottom) {
            // Seeded by the room, so each room's line is its own and the same every launch.
            DrawnRule(seed: "\(room.id)".utf8.reduce(0) { $0 &* 31 &+ UInt64($1) }, delay: delay + 0.5, animated: animated)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.room.\(room.id)")
    }

    private var name: String {
        room.name ?? (room.isSolo ? String(localized: "just me", bundle: .app) : String(localized: "untitled room", bundle: .app))
    }

    @ViewBuilder
    private var people: some View {
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
