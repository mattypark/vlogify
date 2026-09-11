import Foundation
import Observation
import VlogifyEngine

/// Which way clips are shot, app-wide. Landscape by default: most people turn the
/// phone, and landscape clips stack cleanly when a room stitches. Changing it moves
/// the hour stamp, the "rotate to capture" hint, and the stitched layout together --
/// never one without the others.
@MainActor
@Observable
final class CapturePreferences {
    private static let key = "captureOrientation"

    var orientation: StitchPlan.Orientation {
        didSet { UserDefaults.standard.set(orientation.rawValue, forKey: Self.key) }
    }

    init() {
        orientation = UserDefaults.standard.string(forKey: Self.key)
            .flatMap(StitchPlan.Orientation.init(rawValue:)) ?? .landscape
    }

    var isLandscape: Bool { orientation == .landscape }

    func toggle() {
        orientation = isLandscape ? .portrait : .landscape
    }
}
