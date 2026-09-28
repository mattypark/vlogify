import SwiftUI
import VlogifyDesign

/// Two asks, each on its own page, each explained by a drawing and one line, and each
/// firing the system prompt right there -- the moment the reason is on screen.
///
/// One button, and it always leads to the system prompt: a custom screen before a
/// permission request may explain, but may not offer a way around it (5.1.1(iv)). The
/// system prompt is where "don't allow" lives, and a denied camera is explained again on
/// the camera screen with a link to Settings. This screen runs once.
struct PermissionsView: View {
    @Environment(AppState.self) private var state
    @State private var step = 0
    @State private var busy = false

    private var permissions: Permissions { state.permissions }
    private static let textDelay = 0.8

    private var lines: String {
        step == 0
            ? String(localized: "your camera and mic,\nonly while you're filming.", bundle: .app)
            : String(localized: "one nudge an hour.\nsame minute as your friends,\nso you all film the same moment.", bundle: .app)
    }

    private var aside: String {
        step == 0
            ? String(localized: "clips only go to the room you post them in.", bundle: .app)
            : String(localized: "no ads, no streaks, no \"you missed it\".", bundle: .app)
    }

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
                HandwrittenText(text: lines, delay: Self.textDelay)
                HandwrittenText(text: aside, font: .vlogHandSmall, color: .textSoft,
                                delay: HandwrittenText.finish(of: lines, delay: Self.textDelay))
            }
            // Re-written when the step changes.
            .id(step)
            Spacer()
            PillButton(title: "continue", style: .filled, isLoading: busy,
                       drawIn: HandwrittenText.finish(of: lines, delay: Self.textDelay)) { ask() }
                .id(step)
                .accessibilityIdentifier("permissions.continue")
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
