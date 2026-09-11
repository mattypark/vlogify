import SwiftUI
import VlogifyDesign

/// One typed line on a page: no chrome, a grip that appears on focus, a long-press menu.
/// The whole "click to type" interaction is a `TextField` that looks like nothing.
struct NoteBlockView: View {
    @Binding var block: NotesStore.Block
    let onDelete: () -> Void
    let onReturn: () -> Void
    var focus: FocusState<UUID?>.Binding

    var body: some View {
        HStack(alignment: .top, spacing: Space.xs) {
            Image(systemName: "line.3.horizontal")
                .font(Font.system(size: 12, weight: .bold))
                .foregroundStyle(Color.hairline)
                .frame(width: 16, height: 24)
                .opacity(focus.wrappedValue == block.id ? 1 : 0)
            if block.kind == .todo {
                Button {
                    block.done.toggle()
                    Haptics.tap()
                } label: {
                    Image(systemName: block.done ? "checkmark.square.fill" : "square")
                        .font(Font.system(size: 18, weight: .semibold))
                        .foregroundStyle(block.done ? Color.spearmintInk : Color.textSoft)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(SquashButtonStyle())
                .accessibilityLabel(Text(block.done ? "done" : "to do"))
            }
            TextField("", text: $block.text, axis: .vertical)
                .font(block.kind == .heading ? .vlogTitle : .vlogHand)
                .foregroundStyle(block.done ? Color.textSoft : Color.text)
                .strikethrough(block.done)
                .focused(focus, equals: block.id)
                .submitLabel(.return)
                .onSubmit(onReturn)
                .lineLimit(1...20)
                .accessibilityIdentifier("note.block")
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button { block.kind = block.kind == .heading ? .text : .heading } label: {
                Label(block.kind == .heading ? "make text" : "make heading", systemImage: "textformat.size")
            }
            Button { block.kind = block.kind == .todo ? .text : .todo } label: {
                Label(block.kind == .todo ? "make text" : "make to-do", systemImage: "checkmark.square")
            }
            Button(role: .destructive, action: onDelete) { Label("delete", systemImage: "trash") }
        }
    }
}

/// A page's blocks with the tap-anywhere-to-type behaviour. Reused by the day page and
/// the room page.
struct NotesBlockList: View {
    @Environment(AppState.self) private var state
    let scope: NotesStore.Scope
    var placeholder: LocalizedStringKey = "write something…"
    @FocusState private var focused: UUID?

    var body: some View {
        let page = state.notes.page(scope)
        VStack(alignment: .leading, spacing: Space.xs) {
            ForEach(page.blocks) { block in
                NoteBlockView(
                    block: binding(for: block.id),
                    onDelete: { remove(block.id) },
                    onReturn: { insert(after: block.id) },
                    focus: $focused
                )
            }
            if page.blocks.isEmpty {
                Button { insert(after: nil) } label: {
                    Text(placeholder)
                        .font(.vlogHand)
                        .foregroundStyle(Color.textSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: Metrics.hitTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("notes.start")
            } else {
                // Tapping the space under the last block starts a new one.
                Color.clear
                    .frame(height: Space.lg)
                    .contentShape(Rectangle())
                    .onTapGesture { insert(after: page.blocks.last?.id) }
            }
        }
        .accessibilityIdentifier("notes.\(scopeID)")
    }

    private var scopeID: String {
        switch scope {
        case .day: return "day"
        case .room: return "room"
        }
    }

    private func binding(for id: UUID) -> Binding<NotesStore.Block> {
        Binding(
            get: { state.notes.page(scope).blocks.first { $0.id == id } ?? NotesStore.Block() },
            set: { new in state.notes.update(scope) { page in
                if let index = page.blocks.firstIndex(where: { $0.id == id }) { page.blocks[index] = new }
            } }
        )
    }

    private func insert(after id: UUID?) {
        let block = NotesStore.Block()
        state.notes.update(scope) { page in
            if let id, let index = page.blocks.firstIndex(where: { $0.id == id }) {
                page.blocks.insert(block, at: index + 1)
            } else {
                page.blocks.append(block)
            }
        }
        Haptics.tap()
        focused = block.id
    }

    private func remove(_ id: UUID) {
        state.notes.update(scope) { page in page.blocks.removeAll { $0.id == id } }
    }
}
