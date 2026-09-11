import SwiftUI
import VlogifyContract
import VlogifyDesign

struct BlockedUsersView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var people: [Profile] = []

    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    Text("nobody blocked.").font(.vlogBody).foregroundStyle(Color.chalkSoft)
                } else {
                    List(people) { person in
                        HStack {
                            AvatarDisc(profile: person, size: 28)
                            Text(verbatim: person.displayName).font(.vlogBody).foregroundStyle(Color.chalk)
                            Spacer()
                            Button("unblock") {
                                Task {
                                    try? await state.backend.safety.unblock(userID: person.id)
                                    people = (try? await state.backend.safety.blocked()) ?? []
                                }
                            }
                            .font(.vlogCaption).foregroundStyle(Color.orchidInk)
                        }
                        .listRowBackground(Color.surface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("blocked people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("close") { dismiss() }.foregroundStyle(Color.chalk) } }
        }
        .presentationBackground(Color.ink)
        .task { people = (try? await state.backend.safety.blocked()) ?? [] }
        .accessibilityIdentifier("screen.blocked")
    }
}
