import SwiftUI
import VlogifyDesign

/// Two asks, each on its own page, each explained by a drawing and one line, and each
/// firing the system prompt right there -- the moment the reason is on screen.
///
/// "not now" is always there and never punished: a denied camera is explained again on
/// the camera screen with a link to Settings. This screen runs once.
struct PermissionsView: View {
    @Environment(AppState.self) private var state
    @State private var step = 0
    @State private var busy = false

    private var permissions: Permissions { state.permissions }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            Spacer()
            HStack {
                Spacer()
                DoodleSticker(step == 0 ? .camcorder : .bell, scale: 1.1, animated: true, lineWidth: Pen.bold)
                    .id(step)
                Spacer()
            }
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(step == 0
                     ? "your camera and mic,\nonly while you're filming."
                     : "one nudge an hour.\nsame minute as your friends,\nso you all film the same moment.")
                    .font(.vlogBody.weight(.medium))
                    .lineSpacing(5)
                    .foregroundStyle(Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(step == 0
                     ? "clips only go to the room you post them in."
                     : "no ads, no streaks, no \"you missed it\".")
                    .font(.vlogHandSmall)
                    .foregroundStyle(Color.textSoft)
            }
            Spacer()
            VStack(spacing: Space.xs) {
                PillButton(title: "sure", style: .filled, isLoading: busy) { ask() }
                    .accessibilityIdentifier("permissions.continue")
                Button { advance() } label: {
                    Text("not now")
                        .font(.vlogLabel)
                        .foregroundStyle(Color.textSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: Metrics.hitTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("permissions.skip")
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.lg)
        .background(Color.ground.ignoresSafeArea())
        .task { await permissions.refresh() }
        .onAppear { if LaunchArguments.step == 1 { step = 1 } }
        .screen("screen.permissions")
    }

    private func ask() {
        guard !busy else { return }
        busy = true
        Haptics.tap()
        Task {
            defer { busy = false }
            if step == 0 {
                await permissions.requestCamera()
                await permissions.requestMicrophone()
            } else {
                await permissions.requestNotifications()
            }
            advance()
        }
    }

    private func advance() {
        if step == 0 {
            withAnimation(Motion.shift) { step = 1 }
        } else {
            state.permissionsIntroDone = true
        }
    }
}
