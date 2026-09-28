import SwiftUI
import VlogifyContract
import VlogifyDesign

/// Report a clip or a person, and optionally block them. Reports go to the moderation
/// queue; a reported clip is hidden from the whole room at once, and blocking hides the
/// person from every screen immediately.
struct ReportSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    /// Nil when reporting a person rather than one of their clips.
    let clip: Clip?
    let member: Membership?
    @State private var reason: ReportReason = .harassment
    @State private var note = ""
    @State private var alsoBlock = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("reason", selection: $reason) {
                        ForEach(ReportReason.allCases, id: \.self) { Text(label($0)).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .accessibilityIdentifier("report.reason")
                } header: { Text(clip == nil ? "what's wrong?" : "what's wrong with this clip?") }
                .listRowBackground(Color.card)
                Section {
                    TextField("anything else (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                        .accessibilityIdentifier("report.note")
                    if let member {
                        Toggle("also block \(member.profile.displayName)", isOn: $alsoBlock)
                            .accessibilityIdentifier("report.block")
                    }
                }
                .listRowBackground(Color.card)
            }
            .scrollContentBackground(.hidden)
            .background(Color.ground.ignoresSafeArea())
            .navigationTitle("report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("cancel") { dismiss() }.foregroundStyle(Color.text) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("send") { send() }.disabled(busy).foregroundStyle(Color.actionInk)
                        .accessibilityIdentifier("report.send")
                }
            }
        }
        .tint(Color.text)
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.ground)
        .screen("screen.report")
    }

    private func label(_ reason: ReportReason) -> LocalizedStringKey {
        switch reason {
        case .harassment: return "harassment or bullying"
        case .nudity: return "nudity"
        case .violence: return "violence"
        case .spam: return "spam"
        case .impersonation: return "pretending to be someone"
        case .other: return "something else"
        }
    }

    private func send() {
        guard let reporter = state.session?.userID,
              let subject = clip?.memberID ?? member?.userID else { return }
        busy = true
        Task {
            defer { busy = false }
            let report = Report(reporterID: reporter, clipID: clip?.id, userID: subject, reason: reason,
                                note: note.isEmpty ? nil : note, createdAt: Date())
            do {
                try await state.backend.safety.report(report)
                if alsoBlock { try await state.backend.safety.block(userID: subject) }
            } catch {
                // Say so: a report that silently failed is worse than one never sent.
                state.show(.error(String(localized: "couldn't send that. try again.", bundle: .app)))
                return
            }
            Haptics.success()
            state.show(.info(String(localized: "thanks. we'll look at it within a day.", bundle: .app)))
            await state.loadRooms()
            dismiss()
        }
    }
}
