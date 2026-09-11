import SwiftUI
import VlogifyContract
import VlogifyDesign

/// The app after sign-in: a header, the camera or the logs, and the pill bar.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showNewRoom = false
    @State private var showJoin = false
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var openRoom: Room?
    @State private var camera = CameraSession()

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            VStack(spacing: 0) {
                if state.tab == .logs {
                    header
                    LogsTab(openRoom: $openRoom)
                } else {
                    CameraView(camera: camera)
                }
                bar
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationDestination(item: $openRoom) { room in RoomView(room: room) }
        }
        .tint(Color.chalk)
        .sheet(isPresented: $showNewRoom) { NewRoomSheet(created: { openRoom = $0 }) }
        .sheet(isPresented: $showJoin) { JoinRoomSheet(joined: { openRoom = $0 }) }
        .sheet(isPresented: $showProfile) { ProfileView() }
        .sheet(isPresented: $showNotifications) { NotificationsView() }
        .toastOverlay(state.toast)
        .onChange(of: state.pendingJoinCode) { _, code in if code != nil { showJoin = true } }
        .task { await state.loadRooms() }
        .accessibilityIdentifier("screen.home")
    }

    private var header: some View {
        HStack {
            Wordmark()
            Spacer()
            RoundButton(systemImage: "person", label: "profile", size: Metrics.hitTarget + 4) { showProfile = true }
                .accessibilityIdentifier("home.profile")
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.sm)
    }

    private var bar: some View {
        @Bindable var state = state
        return BottomBar(tab: $state.tab) {
            if state.tab == .logs {
                RoundButton(systemImage: "bell", label: "notifications") { showNotifications = true }
                    .accessibilityIdentifier("bar.bell")
            } else {
                RoundButton(systemImage: camera.isTorchOn ? "bolt.fill" : "bolt.slash", label: "flash") { camera.toggleTorch() }
                    .accessibilityIdentifier("bar.flash")
            }
        } trailing: {
            if state.tab == .logs {
                PlusMenu(onCreate: { showNewRoom = true }, onJoin: { showJoin = true })
            } else {
                RoundButton(systemImage: "arrow.triangle.2.circlepath.camera", label: "flip camera") { camera.flip() }
                    .accessibilityIdentifier("bar.flip")
            }
        }
    }
}
