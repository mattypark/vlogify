import SwiftUI
import VlogifyContract
import VlogifyDesign

/// The app after sign-in: a header, today's page or the camera, and the bar.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showNewRoom = false
    @State private var showJoin = false
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var openRoom: Room?
    @State private var camera = CameraSession()
    @State private var showCoachMarks = false
    @State private var showPlus = false

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            VStack(spacing: 0) {
                if state.tab == .logs {
                    VStack(spacing: 0) {
                        header
                        DayPageView(openRoom: $openRoom)
                    }
                    // Over the page only: the bar stays crisp, so `+` can close it again
                    // and the record button keeps its red.
                    .overlay {
                        if showPlus {
                            PlusCard(onCreate: { showNewRoom = true }, onJoin: { showJoin = true }) {
                                withAnimation(Motion.dismiss) { showPlus = false }
                            }
                            .transition(.opacity)
                        }
                    }
                } else {
                    CameraView(camera: camera)
                }
                bar
            }
            .background(Color.ground.ignoresSafeArea())
            .onChange(of: state.tab) { showPlus = false }
            .overlay { if showCoachMarks { CoachMarks { dismissCoachMarks() } } }
            .navigationDestination(item: $openRoom) { room in RoomView(room: room) }
        }
        .tint(Color.text)
        .sheet(isPresented: $showNewRoom) { NewRoomSheet(created: { openRoom = $0 }) }
        .sheet(isPresented: $showJoin) { JoinRoomSheet(joined: { openRoom = $0 }) }
        .sheet(isPresented: $showProfile) { ProfileView() }
        .sheet(isPresented: $showNotifications) { NotificationsView() }
        .toastOverlay(state.toast)
        .onChange(of: state.pendingJoinCode) { _, code in if code != nil { showJoin = true } }
        .task {
            await state.loadRooms()
            #if DEBUG
            if LaunchArguments.screen == "room" { openRoom = state.rooms.first { !$0.isSolo } }
            #endif
        }
        .onAppear {
            #if DEBUG
            switch LaunchArguments.screen {
            case "newRoom": showNewRoom = true
            case "join": showJoin = true
            case "profile": showProfile = true
            case "notifications": showNotifications = true
            case "plus": showPlus = true
            default: break
            }
            #endif
            // First visit only: the page explains itself with handwriting and arrows.
            showCoachMarks = LaunchArguments.screen == "coach"
                || (!UserDefaults.standard.bool(forKey: CoachMarks.seenKey) && !LaunchArguments.isUITesting
                    && LaunchArguments.demo == nil)
        }
        .screen("screen.home")
    }

    private func dismissCoachMarks() {
        UserDefaults.standard.set(true, forKey: CoachMarks.seenKey)
        withAnimation(Motion.dismiss) { showCoachMarks = false }
    }

    private var header: some View {
        HStack(spacing: Space.sm) {
            Wordmark(size: 30)
            Spacer()
            DoodleRound(doodle: .bell, label: "notifications") { showNotifications = true }
                .accessibilityIdentifier("home.bell")
            Button { showProfile = true } label: {
                if let profile = state.profile {
                    AvatarDisc(profile: profile, size: Metrics.hitTarget + 4)
                }
            }
            .buttonStyle(SquashButtonStyle())
            .accessibilityLabel(Text("profile"))
            .accessibilityIdentifier("home.profile")
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.sm)
    }

    private var bar: some View {
        @Bindable var state = state
        return BottomBar(tab: $state.tab) {
            if state.tab == .logs {
                PlusButton { withAnimation(Motion.dismiss) { showPlus.toggle() } }
            } else {
                DoodleRound(doodle: .arrowTurn, label: "flip camera", size: Metrics.barButton) { camera.flip() }
                    .accessibilityIdentifier("bar.flip")
            }
        }
    }
}
