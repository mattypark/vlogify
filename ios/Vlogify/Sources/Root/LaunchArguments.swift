import Foundation
import VlogifyContract

/// DEBUG-only launch arguments, so every screen can be reached in one step for
/// screenshots and the overnight walker without tapping through to build the state
/// by hand.
///
///   -vlogifyDemo full|empty|solo      seed the mock backend (default: whatever is persisted)
///   -vlogifyScreen welcome|permissions|profile|home|camera|newRoom|join|room|player|history|settings|notifications
///   -vlogifyHour 17                   pretend it is this hour (4...27) for the timeline and camera
///   -vlogifyPermissions granted|denied|unasked
///   -vlogifyLocale ko                 forces a language without touching Settings
enum LaunchArguments {
    static var demo: MockBackend.Scenario? {
        #if DEBUG
        guard let raw = value(after: "-vlogifyDemo") else { return nil }
        return MockBackend.Scenario(rawValue: raw)
        #else
        return nil
        #endif
    }

    static var screen: String? {
        #if DEBUG
        return value(after: "-vlogifyScreen")
        #else
        return nil
        #endif
    }

    static var hour: Int? {
        #if DEBUG
        return value(after: "-vlogifyHour").flatMap(Int.init)
        #else
        return nil
        #endif
    }

    /// `-vlogifyLocale ko` forces the app language without touching UserDefaults.
    static var locale: String? {
        #if DEBUG
        return value(after: "-vlogifyLocale")
        #else
        return nil
        #endif
    }

    static var permissions: String? {
        #if DEBUG
        return value(after: "-vlogifyPermissions")
        #else
        return nil
        #endif
    }

    /// True under the UI test runner, so animations that would race the walker are
    /// shortened and the camera is replaced by the sample clip.
    static var isUITesting: Bool {
        CommandLine.arguments.contains("-vlogifyUITest")
    }

    static var usesTemporaryStore: Bool { demo != nil }

    private static func value(after flag: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: flag),
              index + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[index + 1]
    }
}
