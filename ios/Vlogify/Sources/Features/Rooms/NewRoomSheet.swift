import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// A new room is a sentence you fill in: "a room called ___ for me + (3) friends." The
/// blank is where you write the name; the number of friends is circled in pen, the way
/// you would on paper. Two drawn choices above it decide which sentence it is.
struct NewRoomSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let created: (Room) -> Void

    @State private var name = ""
    @State private var type: RoomType = .log
    @State private var capacity = RoomRules.defaultCapacity(for: .log)
    @State private var busy = false
    @State private var invite: Room?
    @FocusState private var naming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                DoodleRound(doodle: .cross, label: "close") { dismiss() }
                    .accessibilityIdentifier("newRoom.close")
                Spacer()
                Text("a new room").font(.vlogTitle).foregroundStyle(Color.text)
                Spacer()
                Color.clear.frame(width: Metrics.hitTarget + 4, height: 1)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    HStack(spacing: Space.sm) {
                        choice(.log, doodle: .friends, title: "with friends")
                        choice(.vlog, doodle: .page, title: "just me")
                    }
                    sentence
                    Text(type == .vlog
                         ? "film as much as you like, whenever. only you see it."
                         : "everyone in it gets the same nudge each hour. you'll get a code to send them.")
                        .font(.vlogBody)
                        .foregroundStyle(Color.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Space.xs)
            }
            .scrollDismissesKeyboard(.interactively)
            PillButton(title: "start it", style: .filled, isLoading: busy) { create() }
                .accessibilityIdentifier("newRoom.create")
        }
        .padding(Space.gutter)
        .background(Color.ground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationBackground(Color.ground)
        .presentationCornerRadius(Radius.frame)
        .sheet(item: $invite) { room in
            InviteView(room: room) {
                invite = nil
                dismiss()
                created(room)
            }
        }
        .screen("screen.newRoom")
    }

    // MARK: Pieces

    private func choice(_ candidate: RoomType, doodle: Doodle, title: LocalizedStringKey) -> some View {
        Button {
            Haptics.tap()
            type = candidate
            capacity = RoomRules.defaultCapacity(for: candidate)
        } label: {
            VStack(spacing: Space.xs) {
                DoodleSticker(doodle, scale: 0.42, lineWidth: 1.8)
                    .frame(height: 64)
                Text(title)
                    .font(.vlogLabel)
                    .foregroundStyle(Color.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
        }
        .buttonStyle(StickerButtonStyle(fill: type == candidate ? .fog : .card, radius: Radius.card))
        .overlay(alignment: .topTrailing) {
            if type == candidate {
                DoodleSticker(.check, scale: 1, lineWidth: 2.2)
                    .padding(Space.sm)
            }
        }
        .accessibilityAddTraits(type == candidate ? .isSelected : [])
        .accessibilityIdentifier("newRoom.type.\(candidate.rawValue)")
    }

    private var sentence: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("a room called")
                .font(.vlogAnnotation)
                .foregroundStyle(Color.text)
            VStack(alignment: .leading, spacing: 2) {
                TextField("anything you like", text: $name)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.never)
                    .font(.vlogAnnotation)
                    .foregroundStyle(Color.text)
                    .focused($naming)
                    .onChange(of: name) { _, new in name = String(new.prefix(RoomRules.maxNameLength)) }
                    .accessibilityIdentifier("newRoom.name")
                // The blank you write on.
                InkStrokes([[CGPoint(x: 0, y: 0.5), CGPoint(x: 0.35, y: 0.3), CGPoint(x: 0.7, y: 0.7), CGPoint(x: 1, y: 0.45)]],
                           box: CGRect(x: 0, y: 0, width: 1, height: 1))
                    .stroke(Color.text, style: Ink.style(1.4))
                    .frame(height: 6)
            }
            if type == .vlog {
                Text("just for me.")
                    .font(.vlogAnnotation)
                    .foregroundStyle(Color.text)
            } else {
                friendCount
            }
        }
    }

    /// "for me + 1 2 3 4 19 friends", with the chosen number circled.
    private var friendCount: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Text("for me +")
                .font(.vlogAnnotation)
                .foregroundStyle(Color.text)
            ForEach(RoomRules.capacityOptions(for: type), id: \.self) { option in
                Button {
                    Haptics.tap()
                    capacity = option
                } label: {
                    Text(verbatim: "\(option - 1)")
                        .font(.vlogAnnotation)
                        .foregroundStyle(Color.text)
                        .frame(minWidth: 34, minHeight: Metrics.hitTarget)
                        .background {
                            if capacity == option {
                                PenShape(.circle, seed: UInt64(option), wobble: 1.4)
                                    .stroke(Color.text, style: Ink.style(1.8))
                                    .frame(width: 38, height: 34)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(option == 20 ? "up to 19 friends" : "\(option - 1) friends"))
                .accessibilityAddTraits(capacity == option ? .isSelected : [])
                .accessibilityIdentifier("newRoom.size.\(option)")
            }
        }
            Text("friends.")
                .font(.vlogAnnotation)
                .foregroundStyle(Color.text)
        }
    }

    private func create() {
        busy = true
        Task {
            defer { busy = false }
            do {
                let draft = RoomDraft(name: RoomRules.normalizedName(name), type: type, capacity: capacity)
                let room = try await state.createRoom(draft)
                Haptics.success()
                if room.isSolo {
                    dismiss()
                    created(room)
                } else {
                    invite = room
                }
            } catch {
                state.show(.error(String(localized: "couldn't start the room. try again.", bundle: .app)))
            }
        }
    }
}
