import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// Six characters in, a preview of the room, one tap to join.
struct JoinRoomSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let joined: (Room) -> Void

    @State private var input = ""
    @State private var preview: (room: Room, memberCount: Int)?
    @State private var problem: String?
    @State private var busy = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("join with code").font(.vlogTitle).foregroundStyle(Color.chalk)
                Spacer()
                RoundButton(systemImage: "xmark", label: "close", size: Metrics.hitTarget + 4) { dismiss() }
                    .accessibilityIdentifier("join.close")
            }
            TextField("ABC-123", text: $input)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(Font.system(size: 32, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(Color.chalk)
                .multilineTextAlignment(.center)
                .padding(Space.md)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
                .focused($focused)
                .onChange(of: input) { _, new in
                    let normalized = InviteCode.normalize(new)
                    if normalized.count > InviteCode.length { input = String(normalized.prefix(InviteCode.length)) }
                    lookup()
                }
                .accessibilityIdentifier("join.code")
            if let problem {
                Text(verbatim: problem).font(.vlogCaption).foregroundStyle(Color.emberInk)
                    .accessibilityIdentifier("join.error")
            }
            if let preview {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: preview.room.name ?? String(localized: "untitled log"))
                            .font(.vlogCardTitle).foregroundStyle(Color.chalk)
                        Text("\(preview.memberCount) of \(preview.room.capacity) in")
                            .font(.vlogCaption).foregroundStyle(Color.chalkSoft)
                    }
                    Spacer()
                    Text(verbatim: preview.room.type.rawValue).font(.vlogCaption).foregroundStyle(Color.chalkSoft)
                }
                .padding(Space.md)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                .accessibilityIdentifier("join.preview")
            }
            Spacer()
            PillButton(title: "join", style: .accent, isLoading: busy) { join() }
                .disabled(preview == nil)
                .opacity(preview == nil ? 0.5 : 1)
                .accessibilityIdentifier("join.submit")
        }
        .padding(Space.gutter)
        .background(Color.ink.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationBackground(Color.ink)
        .onAppear {
            if let pending = state.pendingJoinCode {
                input = pending.value
                state.pendingJoinCode = nil
            }
            focused = true
        }
        .accessibilityIdentifier("screen.join")
    }

    private func lookup() {
        problem = nil
        preview = nil
        guard InviteCode.normalize(input).count == InviteCode.length else { return }
        guard let code = InviteCode(input) else {
            problem = String(localized: "that doesn't look like a code. check for a typo.")
            return
        }
        Task {
            do {
                preview = try await state.backend.rooms.preview(code: code)
            } catch {
                problem = String(localized: "no room with that code.")
            }
        }
    }

    private func join() {
        guard let code = InviteCode(input) else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let room = try await state.joinRoom(code: code)
                Haptics.success()
                dismiss()
                joined(room)
            } catch ContractError.roomFull {
                problem = String(localized: "that room is full.")
                Haptics.error()
            } catch {
                problem = String(localized: "couldn't join. try again.")
            }
        }
    }
}
