import SwiftUI
import VlogifyContract

@main
struct VlogifyApp: App {
    @State private var state: AppState?

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
