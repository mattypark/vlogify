import SwiftUI
import VlogifyDesign

/// Which screen the app is on, decided from state and nothing else.
struct RootGate: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            switch state.gate {
            case .welcome: WelcomeView()
            case .language: LanguageView()
            case .permissions: PermissionsView()
            case .profile: ProfileSetupView()
            case .home: HomeView()
            }
        }
        .environment(\.locale, state.language?.locale ?? .current)
        .preferredColorScheme(.light)
        .animation(Motion.shift, value: state.gate)
    }
}
