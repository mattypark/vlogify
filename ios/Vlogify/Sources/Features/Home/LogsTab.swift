import SwiftUI
import VlogifyContract
import VlogifyDesign

/// The room list, or the explainer when there is nothing yet.
struct LogsTab: View {
    @Environment(AppState.self) private var state
    @Binding var openRoom: Room?

    var body: some View {
        if state.rooms.isEmpty {
            EmptyHomeView()
        } else {
            ScrollView {
                LazyVStack(spacing: Space.sm) {
                    ForEach(state.rooms) { room in
                        RoomCard(room: room, log: state.roomProgress[room.id]) { openRoom = room }
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.lg)
                .padding(.bottom, Space.md)
            }
            .refreshable { await state.loadRooms() }
            .screen("home.rooms")
        }
    }
}

/// "your day, side by side." with the two ways to start.
struct EmptyHomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Spacer()
            Text("your day, side by side.")
                .font(.vlogTitle)
                .foregroundStyle(Color.text)
                .padding(.bottom, Space.xs)
            step(1) {
                HStack(spacing: Space.xs) {
                    Text("tap").font(.vlogBody).foregroundStyle(Color.text)
                    Image(systemName: "plus.circle").foregroundStyle(Color.text)
                    Text("to start").font(.vlogBody).foregroundStyle(Color.text)
                }
                HStack(spacing: Space.xs) {
                    Chip(text: String(localized: "create log", bundle: .app))
                    Text("(new group)").font(.vlogBody).foregroundStyle(Color.textSoft)
                }
                HStack(spacing: Space.xs) {
                    Chip(text: String(localized: "join log", bundle: .app))
                    Text("(with a code)").font(.vlogBody).foregroundStyle(Color.textSoft)
                }
            }
            step(2) {
                Text("add a 2s clip every hour.").font(.vlogBody).foregroundStyle(Color.text)
                Text("see everyone's day\ncome together.").font(.vlogBody).foregroundStyle(Color.text)
                Text("solo logs don't have limits.").font(.vlogBody).foregroundStyle(Color.text)
            }
            Text("day resets at 4AM.\nfind past days in history.")
                .font(.vlogCaption)
                .foregroundStyle(Color.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .background(Color.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .padding(.top, Space.sm)
            Spacer()
            HStack(alignment: .bottom) {
                DoodleSticker(.turtle).padding(.leading, Space.md)
                Spacer()
                DoodleSticker(.ufo).padding(.trailing, Space.md)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
            .padding(.bottom, Space.xs)
        }
        .padding(.horizontal, Space.gutter)
        .screen("home.empty")
    }

    private func step<Content: View>(_ number: Int, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Text(verbatim: "\(number)")
                .font(Font.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.paper)
                .frame(width: 24, height: 24)
                .background(Color.soot, in: Circle())
            VStack(alignment: .leading, spacing: Space.xs, content: content)
        }
    }
}

/// One room on the home list: name, who is in it, today's dots, the next ping.
struct RoomCard: View {
    @Environment(AppState.self) private var state
    let room: Room
    let log: DayLog?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Text(verbatim: room.name ?? (room.isSolo ? String(localized: "just me", bundle: .app) : String(localized: "untitled log", bundle: .app)))
                        .font(.vlogCardTitle)
                        .foregroundStyle(Color.text)
                    Spacer()
                    if room.isSolo {
                        Text("vlog").font(.vlogCaption).foregroundStyle(Color.textSoft)
                    } else {
                        HStack(spacing: -8) {
                            ForEach((log?.members ?? []).prefix(5)) { member in
                                AvatarDisc(profile: member.profile, size: 24)
                                    .overlay(Circle().stroke(Color.card, lineWidth: 2))
                            }
                        }
                    }
                }
                HourDots(log: log, userID: state.session?.userID, currentSlot: state.clock.currentSlot)
                HStack {
                    Text(verbatim: statusLine)
                        .font(.vlogCaption)
                        .foregroundStyle(Color.textSoft)
                    Spacer()
                    Image(systemName: "chevron.right").font(.vlogCaption).foregroundStyle(Color.textSoft)
                }
            }
            .padding(Space.md)
            .background(Color.card, in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).stroke(Color.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.room.\(room.id)")
    }

    private var statusLine: String {
        if room.isSolo {
            let count = log?.clips.count ?? 0
            return String(localized: "\(count) clips today", bundle: .app)
        }
        if state.hasPosted(in: room, slot: state.clock.currentSlot) {
            return String(localized: "posted \(state.clock.currentSlot.label). next ping in \(Clock.countdown(state.clock.secondsUntilPing(room: room.id)))", bundle: .app)
        }
        return String(localized: "it's \(state.clock.currentSlot.label). add your clip.", bundle: .app)
    }
}
