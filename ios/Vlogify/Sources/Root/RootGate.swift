import SwiftUI
import VlogifyDesign

/// Which screen the app is on, decided from state and nothing else.
struct RootGate: View {
    @Environment(AppState.self) private var state
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch state.gate {
            case .welcome: WelcomeView()
            case .language: LanguageView()
            case .permissions: PermissionsView()
            case .profile: ProfileSetupView()
            case .rooms: RoomsIntroView()
            case .home: HomeView()
            }
        }
        .environment(\.locale, state.language?.locale ?? .current)
        .preferredColorScheme(.light)
        .animation(Motion.shift, value: state.gate)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await state.foreground() }
        }
    }
}
