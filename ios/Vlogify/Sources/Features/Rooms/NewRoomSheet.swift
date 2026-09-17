import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// Name, type, size. The check button in the corner creates it.
struct NewRoomSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let created: (Room) -> Void

    @State private var name = ""
    @State private var type: RoomType = .log
    @State private var capacity = RoomRules.defaultCapacity(for: .log)
    @State private var busy = false
    @State private var invite: Room?

    private var types: [RoomType] {
        [.log] + (FeatureFlags.stackRooms ? [.stack] : []) + [.vlog]
    }

    var body: some View {
        // The header stays put; the form scrolls. With the keyboard up on a small phone
        // the create button used to be pushed off the top of the sheet.
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                RoundButton(systemImage: "xmark", label: "close", size: Metrics.hitTarget + 4) { dismiss() }
                    .accessibilityIdentifier("newRoom.close")
                Spacer()
                Text("new room").font(.vlogTitle).foregroundStyle(Color.text)
                Spacer()
                RoundButton(systemImage: "checkmark", label: "create", size: Metrics.hitTarget + 4,
                            tint: .text, fill: .action) { create() }
                    .disabled(busy)
                    .accessibilityIdentifier("newRoom.create")
            }
            ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
            TextField("room name (optional)", text: $name)
                .submitLabel(.done)
                .textInputAutocapitalization(.never)
                .font(.vlogBody)
                .foregroundStyle(Color.text)
                .padding(Space.md)
                .sticker(fill: .card, radius: Radius.pill)
                .stickerRoom()
                .onChange(of: name) { _, new in name = String(new.prefix(RoomRules.maxNameLength)) }
                .accessibilityIdentifier("newRoom.name")

            Text("room type").font(.vlogCardTitle).foregroundStyle(Color.text)
            HStack(spacing: Space.sm) {
                ForEach(types, id: \.self) { candidate in
                    RoomTypeCard(type: candidate, selected: type == candidate) {
                        Haptics.tap()
                        type = candidate
                        capacity = RoomRules.defaultCapacity(for: candidate)
                    }
                }
            }
            Text(caption)
                .font(.vlogCaption)
                .foregroundStyle(Color.textSoft)
                .frame(maxWidth: .infinity)

            if RoomRules.capacityOptions(for: type).count > 1 {
                Divider().overlay(Color.hairline)
                Text("room size").font(.vlogCardTitle).foregroundStyle(Color.text)
                SizePicker(type: type, capacity: $capacity)
                Text(capacity == 20 ? "you + up to 19 friends" : "you + \(capacity - 1) friends")
                    .font(.vlogCaption)
                    .foregroundStyle(Color.textSoft)
                    .frame(maxWidth: .infinity)
            }
            }
            }
            .scrollDismissesKeyboard(.interactively)
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

    private var caption: LocalizedStringKey {
        switch type {
        case .log: return "you and friends"
        case .stack: return "24hrs, up to 40 friends"
        case .vlog: return "just you"
        case .zip: return "right now"
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
                state.show(.error(String(localized: "couldn't create the room. try again.", bundle: .app)))
            }
        }
    }
}
