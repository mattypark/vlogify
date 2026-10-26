import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// The last page of onboarding: get into a room with friends before the app opens, not
/// after someone finds `+`. Join a friend's code (already filled in when you came from
/// their link), start your own and send the code, or carry on with just your own vlog.
///
/// Shown once, and only to someone without a friends' room yet.
struct RoomsIntroView: View {
    @Environment(AppState.self) private var state
    @State private var showJoin = false
    @State private var showNewRoom = false
    /// Read once: the join sheet takes the pending code off `state` when it opens.
    @State private var linkCode: InviteCode?

    private static let textDelay = 0.8

    private var lines: String { String(localized: "vlog with friends?", bundle: .app) }

    private var aside: String {
        linkCode == nil
            ? String(localized: "a room is you + friends.\neveryone films the same hour,\nand the day plays back as one.", bundle: .app)
            : String(localized: "a friend sent you their room.\none tap and you're in.", bundle: .app)
    }

    private var buttonsDelay: Double {
        HandwrittenText.finish(of: aside, delay: HandwrittenText.finish(of: lines, delay: Self.textDelay))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            Spacer()
            HStack {
                Spacer()
                DoodleSticker(.friends, scale: 1.1, animated: true, lineWidth: Pen.bold)
                Spacer()
            }
            VStack(alignment: .leading, spacing: Space.sm) {
                HandwrittenText(text: lines, font: .vlogTitle, delay: Self.textDelay)
                HandwrittenText(text: aside, font: .vlogHandSmall, color: .textSoft,
                                delay: HandwrittenText.finish(of: lines, delay: Self.textDelay))
            }
            Spacer()
            VStack(spacing: Space.sm) {
                if let linkCode {
                    PillButton(title: "join \(linkCode.formatted)", style: .filled, drawIn: buttonsDelay) { showJoin = true }
                        .accessibilityIdentifier("roomsIntro.join")
                } else {
                    PillButton(title: "join a friend's room", style: .filled, drawIn: buttonsDelay) { showJoin = true }
                        .accessibilityIdentifier("roomsIntro.join")
                    PillButton(title: "start a room", style: .outlined, drawIn: buttonsDelay + 0.2) { showNewRoom = true }
                        .accessibilityIdentifier("roomsIntro.create")
                }
                Button { finish() } label: {
                    Text("just me for now")
                        .font(.vlogLabel)
                        .foregroundStyle(Color.textSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: Metrics.hitTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("roomsIntro.skip")
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.lg)
        .background(Color.ground.ignoresSafeArea())
        .sheet(isPresented: $showJoin) {
            JoinRoomSheet { _ in finish() }
        }
        .sheet(isPresented: $showNewRoom) {
            // Called once the invite code has been shown and closed.
            NewRoomSheet { _ in finish() }
        }
        .onAppear {
            linkCode = state.pendingJoinCode
            if linkCode != nil { showJoin = true }
        }
        .screen("screen.roomsIntro")
    }

    private func finish() {
        Haptics.success()
        state.roomsIntroDone = true
    }
}
