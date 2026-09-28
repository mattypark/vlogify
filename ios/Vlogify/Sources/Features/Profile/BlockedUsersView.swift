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
                    Text("nobody blocked.").font(.vlogBody).foregroundStyle(Color.textSoft)
                } else {
                    List(people) { person in
                        HStack {
                            AvatarDisc(profile: person, size: 28)
                            Text(verbatim: person.displayName).font(.vlogBody).foregroundStyle(Color.text)
                            Spacer()
                            Button("unblock") {
                                Task {
                                    try? await state.backend.safety.unblock(userID: person.id)
                                    people = (try? await state.backend.safety.blocked()) ?? []
                                }
                            }
                            .font(.vlogCaption).foregroundStyle(Color.actionInk)
                        }
                        .listRowBackground(Color.card)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ground.ignoresSafeArea())
            .navigationTitle("blocked people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("close") { dismiss() }.font(.vlogLabel).foregroundStyle(Color.text) } }
        }
        .presentationBackground(Color.ground)
        .task { people = (try? await state.backend.safety.blocked()) ?? [] }
        .screen("screen.blocked")
    }
}
