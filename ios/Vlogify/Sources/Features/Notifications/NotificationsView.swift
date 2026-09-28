import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// What is coming: the next ping per room. Room events (a friend posted) arrive here
/// once the backend session wires push; until then it is the schedule.
struct NotificationsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private var pinged: [Room] { state.rooms.filter { RoomRules.pings($0.type) } }

    var body: some View {
        NavigationStack {
            Group {
                if pinged.isEmpty {
                    VStack(spacing: Space.sm) {
                        DoodleSticker(.bell, scale: 0.6)
                        Text("no nudges yet. rooms with friends get one every hour.")
                            .font(.vlogBody).foregroundStyle(Color.textSoft).multilineTextAlignment(.center)
                    }
                    .padding(Space.xl)
                } else {
                    List(pinged) { room in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: room.name ?? String(localized: "untitled room", bundle: .app)).font(.vlogBody).foregroundStyle(Color.text)
                                Text("next nudge in \(Clock.countdown(state.clock.secondsUntilPing(room: room.id)))")
                                    .font(.vlogCaption).foregroundStyle(Color.textSoft)
                            }
                            Spacer()
                            DoodleSticker(.bell, scale: 0.18, lineWidth: 1.4)
                        }
                        .listRowBackground(Color.card)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ground.ignoresSafeArea())
            .navigationTitle("nudges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("close") { dismiss() }.font(.vlogLabel).foregroundStyle(Color.text) } }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.ground)
        .screen("screen.notifications")
    }
}
