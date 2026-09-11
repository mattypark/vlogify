import SwiftUI
import VlogifyDesign

/// The terminal. Types out why it needs each permission, asks, ticks it off.
///
/// Denial is not a wall: a denied camera is explained again on the camera screen with
/// a link to Settings. This screen runs once.
struct PermissionsView: View {
    @Environment(AppState.self) private var state
    @State private var step = 0
    @State private var lineDone = false

    private var permissions: Permissions { state.permissions }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            DoodleSticker(.mascot, scale: 0.28)
                .padding(.bottom, Space.xs)
            TypewriterText(text: "→ permissions", bold: true, color: .chalk)
            TypewriterText(text: String(localized: "we need a few things first…", bundle: .app))
                .padding(.bottom, Space.sm)

            row(index: 0, name: "camera", status: permissions.camera,
                detail: String(localized: "capture 2s clips to share with close friends.", bundle: .app))
            if step >= 1 {
                row(index: 1, name: "microphone", status: permissions.microphone,
                    detail: String(localized: "record sound while capturing clips.", bundle: .app))
            }
            if step >= 2 {
                row(index: 2, name: "notifications", status: permissions.notifications,
                    detail: String(localized: "one nudge an hour, same moment as your friends.", bundle: .app))
            }
            if step >= 3 {
                TypewriterText(text: String(localized: "clips are only visible to the room you post them in.", bundle: .app))
                    .padding(.top, Space.sm)
            }
            Spacer()
            if lineDone {
                Button {
                    Haptics.tap()
                    advance()
                } label: {
                    Text(step >= 3 ? "done →" : "continue →")
                        .font(.vlogMonoBold)
                        .foregroundStyle(Color.chalk)
                        .underline()
                        .frame(height: Metrics.hitTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("permissions.continue")
                .transition(.opacity)
            }
        }
        .padding(Space.gutter)
        .padding(.top, Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.ink.ignoresSafeArea())
        .task { await permissions.refresh() }
        .screen("screen.permissions")
    }

    private func row(index: Int, name: String, status: Permissions.Status, detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.xs) {
            Group {
                if status == .granted {
                    Text(verbatim: "✓").foregroundStyle(Color.spearmintInk)
                } else if status == .denied {
                    Text(verbatim: "✗").foregroundStyle(Color.emberInk)
                } else {
                    Text(verbatim: " ")
                }
            }
            .font(.vlogMonoBold)
            .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                if step == index {
                    (Text(verbatim: name).font(.vlogMonoBold).foregroundStyle(Color.chalk)
                     + Text(verbatim: " ").font(.vlogMono))
                    TypewriterText(text: detail, onDone: { lineDone = true })
                } else {
                    Text(verbatim: name).font(.vlogMonoBold).foregroundStyle(status == .granted ? Color.chalkSoft : Color.chalk)
                    if status == .denied {
                        Button("open settings") { openSettings() }
                            .font(.vlogMono).foregroundStyle(Color.emberInk).underline()
                    }
                }
            }
        }
        .accessibilityIdentifier("permissions.\(name)")
    }

    private func advance() {
        lineDone = false
        Task {
            switch step {
            case 0: await permissions.requestCamera()
            case 1: await permissions.requestMicrophone()
            case 2: await permissions.requestNotifications()
            default:
                state.permissionsIntroDone = true
                return
            }
            withAnimation(Motion.shift) { step += 1 }
            if step == 3 { lineDone = true }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
