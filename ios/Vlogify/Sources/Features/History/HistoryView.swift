import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// Past days with at least one clip, newest first.
struct HistoryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let room: Room
    let pick: (DayKey) -> Void
    @State private var days: [DayKey] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Group {
                if !loaded {
                    ProgressView().tint(Color.text)
                } else if days.isEmpty {
                    Text("no past days yet. tomorrow, today will be here.")
                        .font(.vlogBody).foregroundStyle(Color.textSoft)
                        .multilineTextAlignment(.center).padding(Space.xl)
                } else {
                    List(days, id: \.description) { day in
                        Button { pick(day) } label: {
                            HStack {
                                Text(verbatim: state.clock.formatted(day)).font(.vlogBody).foregroundStyle(Color.text)
                                Spacer()
                                if day == state.clock.today { Text("today").font(.vlogCaption).foregroundStyle(Color.actionInk) }
                                Image(systemName: "chevron.right").font(.vlogCaption).foregroundStyle(Color.textSoft)
                            }
                        }
                        .listRowBackground(Color.card)
                        .accessibilityIdentifier("history.day.\(day)")
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ground.ignoresSafeArea())
            .navigationTitle("history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("close") { dismiss() }.foregroundStyle(Color.text) } }
        }
        .presentationBackground(Color.ground)
        .task {
            days = (try? await state.backend.clips.history(roomID: room.id)) ?? []
            loaded = true
        }
        .screen("screen.history")
    }
}
