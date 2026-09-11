import SwiftUI
import VlogifyDesign

/// Which screen the app is on, decided from state and nothing else.
struct RootGate: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            switch state.gate {
            case .welcome: WelcomeView()
            case .permissions: PermissionsView()
            case .profile: ProfileSetupView()
            case .home: HomeView()
            }
        }
        .preferredColorScheme(state.gate == .welcome ? .light : .dark)
        .animation(Motion.shift, value: state.gate)
    }
}
