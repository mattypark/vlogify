import SwiftUI
import VlogifyContract

@main
struct VlogifyApp: App {
    @State private var state: AppState?

    init() {
        FontRegistration.assertBundled()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let state {
                    RootGate()
                        .environment(state)
                        .onOpenURL { state.handle(url: $0) }
                } else {
                    // The ink launch colour, held until the backend is chosen. A few
                    // milliseconds; the launch metric test measures it.
                    Color.ground.ignoresSafeArea()
                }
            }
            .task {
                guard state == nil else { return }
                let clock = Clock()
                let cache = LocalMediaCache()
                let backend = await BackendRoot.make(cache: cache, clock: clock)
                let built = AppState(backend: backend, clock: clock, permissions: Permissions(),
                                     scheduler: HourlyScheduler(), cache: cache)
                await built.restoreSession()
                LaunchArguments.apply(to: built)
                state = built
            }
        }
    }
}

extension LaunchArguments {
    /// `-vlogifyScreen camera` lands on the camera tab; the sheets are reached by the
    /// walker through their buttons so that the buttons themselves get tested.
    @MainActor
    static func apply(to state: AppState) {
        #if DEBUG
        if screen == "camera" { state.tab = .camera }
        if screen == "logs" { state.tab = .logs }
        #endif
    }
}

import VlogifyDesign

/// `Font.custom` falls back to the system face **silently** when a PostScript name misses,
/// so a font that failed to bundle ships as "the app looks slightly generic" rather than as
/// a crash. This turns it into a debug crash instead.
enum FontRegistration {
    static func assertBundled() {
        #if DEBUG
        for name in [Typeface.bagel, Typeface.gloria] {
            assert(UIFont(name: name, size: 12) != nil,
                   "Font \(name) is not in the bundle. Check UIAppFonts in project.yml and Resources/Fonts.")
        }
        #endif
    }
}
