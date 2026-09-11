import SwiftUI
import VlogifyContract
import VlogifyDesign

/// Report a clip, and optionally block the person. Reports go to the backend queue
/// (the mock counts them); blocking hides them from every screen immediately.
struct ReportSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let clip: Clip
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
                } header: { Text("what's wrong with this clip?") }
                .listRowBackground(Color.surface)
                Section {
                    TextField("anything else (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                        .accessibilityIdentifier("report.note")
                    if let member {
                        Toggle("also block \(member.profile.displayName)", isOn: $alsoBlock)
                            .accessibilityIdentifier("report.block")
                    }
                }
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("cancel") { dismiss() }.foregroundStyle(Color.chalk) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("send") { send() }.disabled(busy).foregroundStyle(Color.orchidInk)
                        .accessibilityIdentifier("report.send")
                }
            }
        }
        .tint(Color.chalk)
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.ink)
        .accessibilityIdentifier("screen.report")
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
        guard let reporter = state.session?.userID else { return }
        busy = true
        Task {
            defer { busy = false }
            let report = Report(reporterID: reporter, clipID: clip.id, userID: clip.memberID, reason: reason,
                                note: note.isEmpty ? nil : note, createdAt: Date())
            try? await state.backend.safety.report(report)
            if alsoBlock { try? await state.backend.safety.block(userID: clip.memberID) }
            Haptics.success()
            state.show(.info(String(localized: "thanks. we'll look at it.")))
            await state.loadRooms()
            dismiss()
        }
    }
}
