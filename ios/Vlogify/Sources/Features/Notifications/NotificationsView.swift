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
                        Image(systemName: "bell.slash").font(Font.system(size: 32)).foregroundStyle(Color.chalkSoft)
                        Text("no pings yet. logs with friends ping every hour.")
                            .font(.vlogBody).foregroundStyle(Color.chalkSoft).multilineTextAlignment(.center)
                    }
                    .padding(Space.xl)
                } else {
                    List(pinged) { room in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: room.name ?? String(localized: "untitled log")).font(.vlogBody).foregroundStyle(Color.chalk)
                                Text("next ping in \(Clock.countdown(state.clock.secondsUntilPing(room: room.id)))")
                                    .font(.vlogCaption).foregroundStyle(Color.chalkSoft)
                            }
                            Spacer()
                            Image(systemName: "bell").foregroundStyle(Color.orchidInk)
                        }
                        .listRowBackground(Color.surface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("pings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("close") { dismiss() }.foregroundStyle(Color.chalk) } }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.ink)
        .accessibilityIdentifier("screen.notifications")
    }
}
