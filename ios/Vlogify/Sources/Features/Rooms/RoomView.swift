import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// A room's day: one row per hour from 4:00, a tile per member.
struct RoomView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let room: Room

    @State private var day: DayKey?
    @State private var log: DayLog?
    @State private var playing: Clip?
    @State private var showInvite = false
    @State private var showHistory = false
    @State private var showPlayer = false
    @State private var reporting: Clip?
    @State private var confirmLeave = false
    @State private var thumbnails: Thumbnails?

    private var shownDay: DayKey { day ?? state.clock.today }
    private var isToday: Bool { shownDay == state.clock.today }

    var body: some View {
        // ZStack rather than the reader as the root: an accessibility container has to
        // be a real view for the walker to find `screen.room`.
        ZStack { timeline }
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle(room.name ?? String(localized: room.isSolo ? "just me" : "untitled log"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showPlayer = true } label: { Label("play the day", systemImage: "play.rectangle") }
                            .disabled(log?.clips.isEmpty ?? true)
                        Button { showHistory = true } label: { Label("history", systemImage: "calendar") }
                        if !room.isSolo {
                            Button { showInvite = true } label: { Label("invite", systemImage: "person.badge.plus") }
                        }
                        Divider()
                        Button(role: .destructive) { confirmLeave = true } label: {
                            Label(room.isSolo ? "delete this vlog" : "leave room", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundStyle(Color.chalk)
                    }
                    .accessibilityIdentifier("room.menu")
                }
            }
            .task(id: shownDay) { await load() }
            .sheet(isPresented: $showInvite) { InviteView(room: room) }
            .sheet(isPresented: $showHistory) {
                HistoryView(room: room) { picked in day = picked; showHistory = false }
            }
            .fullScreenCover(isPresented: $showPlayer) {
                if let log { DayPlayerView(room: room, log: log) }
            }
            .fullScreenCover(item: $playing) { clip in ClipPlayerView(clip: clip) }
            .sheet(item: $reporting) { clip in ReportSheet(clip: clip, member: log?.members.first { $0.userID == clip.memberID }) }
            .confirmationDialog(room.isSolo ? "delete this vlog?" : "leave this room?", isPresented: $confirmLeave, titleVisibility: .visible) {
                Button(room.isSolo ? "delete" : "leave", role: .destructive) {
                    Task { await state.leaveRoom(room); dismiss() }
                }
            } message: {
                Text(room.isSolo ? "your clips in it go too." : "you'll need a new code to come back.")
            }
            .environment(thumbnails ?? Thumbnails(media: state.backend.media, local: state.cache))
            .onAppear { if thumbnails == nil { thumbnails = Thumbnails(media: state.backend.media, local: state.cache) } }
            .screen("screen.room")
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Space.lg) {
                    membersRow
                    if let log {
                        ForEach(rows(for: log), id: \.slot.hour) { row in
                            hourRow(row, log: log)
                                .id(row.slot.hour)
                        }
                    } else {
                        ProgressView().tint(Color.chalk).frame(maxWidth: .infinity).padding(.top, Space.xxl)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxl)
            }
            .onChange(of: log?.day) { _, _ in
                if isToday { withAnimation { proxy.scrollTo(state.clock.currentSlot.hour, anchor: .center) } }
            }
        }
    }

    private var membersRow: some View {
        HStack(spacing: Space.sm) {
            if let log {
                ForEach(log.members) { member in
                    AvatarDisc(profile: member.profile)
                        .contextMenu {
                            if member.userID != state.session?.userID {
                                Button(role: .destructive) { reporting = nil; Task { await block(member) } } label: {
                                    Label("block \(member.profile.displayName)", systemImage: "hand.raised")
                                }
                                if room.ownerID == state.session?.userID {
                                    Button(role: .destructive) { Task { await remove(member) } } label: {
                                        Label("remove from room", systemImage: "person.badge.minus")
                                    }
                                }
                            }
                        }
                }
            }
            Spacer()
            if !isToday {
                Button { day = nil } label: {
                    Chip(text: String(localized: "back to today"))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("room.today")
            } else if !room.isSolo {
                Button { showInvite = true } label: {
                    Label("invite", systemImage: "plus").font(.vlogCaption).foregroundStyle(Color.chalk)
                        .padding(.horizontal, Space.sm).frame(height: 32)
                        .background(Color.surface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("room.invite")
            }
        }
        .padding(.top, Space.sm)
        .overlay(alignment: .bottomLeading) {
            Text(verbatim: isToday ? String(localized: "today") : state.clock.formatted(shownDay))
                .font(.vlogCaption).foregroundStyle(Color.chalkSoft)
                .offset(y: Space.lg)
        }
        .padding(.bottom, Space.md)
    }

    struct Row { let slot: Slot; let isCurrent: Bool; let isFuture: Bool }

    /// Past and current hours, newest first for today so the live hour is at the top;
    /// a past day is chronological.
    private func rows(for log: DayLog) -> [Row] {
        let current = state.clock.currentSlot
        let all = DayClock.slots(of: log.day)
        if isToday {
            let shown = all.filter { $0.hour <= current.hour }
            return shown.reversed().map { Row(slot: $0, isCurrent: $0 == current, isFuture: false) }
        }
        let posted = Set(log.postedSlots)
        return all.filter { posted.contains($0) }.map { Row(slot: $0, isCurrent: false, isFuture: false) }
    }

    private func hourRow(_ row: Row, log: DayLog) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text(verbatim: row.slot.label)
                    .font(Font.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(row.isCurrent ? Color.orchidInk : Color.chalk)
                if row.isCurrent {
                    Text("now").font(.vlogCaption).foregroundStyle(Color.orchidInk)
                }
                Spacer()
                if row.isCurrent, !room.isSolo, !state.hasPosted(in: room, slot: row.slot) {
                    Button {
                        state.tab = .camera
                        dismiss()
                    } label: {
                        Chip(text: String(localized: "add clip"), selected: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("room.addClip")
                }
            }
            let clips = log.clips(in: row.slot)
            if room.isSolo {
                if clips.isEmpty {
                    Text("nothing this hour").font(.vlogCaption).foregroundStyle(Color.chalkSoft)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.xs) {
                            ForEach(clips) { clip in
                                if let me = log.members.first {
                                    ClipTile(member: me, clip: clip, isMe: true) { playing = $0 }
                                        .frame(width: 120)
                                        .contextMenu { deleteButton(clip) }
                                }
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: Space.xs) {
                    ForEach(log.members) { member in
                        let clip = log.clip(from: member.userID, in: row.slot)
                        ClipTile(member: member, clip: clip, isMe: member.userID == state.session?.userID) { playing = $0 }
                            .contextMenu {
                                if let clip {
                                    if member.userID == state.session?.userID {
                                        deleteButton(clip)
                                    } else {
                                        Button { reporting = clip } label: { Label("report", systemImage: "flag") }
                                    }
                                }
                            }
                    }
                }
            }
        }
        .screen("room.hour.\(row.slot.hour)")
    }

    private func deleteButton(_ clip: Clip) -> some View {
        Button(role: .destructive) {
            Task {
                try? await state.backend.clips.delete(clipID: clip.id)
                await load()
                await state.loadRooms()
            }
        } label: { Label("delete my clip", systemImage: "trash") }
    }

    private func load() async {
        log = try? await state.backend.clips.day(roomID: room.id, day: shownDay)
    }

    private func block(_ member: Membership) async {
        try? await state.backend.safety.block(userID: member.userID)
        state.show(.info(String(localized: "\(member.profile.displayName) blocked.")))
        await load()
    }

    private func remove(_ member: Membership) async {
        try? await state.backend.rooms.removeMember(userID: member.userID, from: room.id)
        await load()
    }
}
