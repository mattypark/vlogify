import SwiftUI

/// Every animation in Vlogify, named. There are four, and there is no fifth.
///
/// Springs rather than duration curves: a clip landing on the timeline is a physical
/// event and a cubic ease reads as a screen updating rather than as a moment arriving.
public enum Motion {
    /// A pill selecting, a check button pressing. Quick, slight overshoot.
    public static let tap = Animation.spring(response: 0.24, dampingFraction: 0.6)
    /// A clip landing in its tile, a room card appearing.
    public static let land = Animation.spring(response: 0.42, dampingFraction: 0.74)
    /// Sheets, the plus menu, anything structural.
    public static let shift = Animation.spring(response: 0.34, dampingFraction: 0.9)
    /// The two-second recording ring. Linear on purpose: it is a clock.
    public static let ring = Animation.linear(duration: 2)

    /// Honors Reduce Motion by dropping the spring, not the state change.
    ///
    /// Returning `nil` rather than a fast spring is deliberate: the setting means "do
    /// not move things", and a 60ms bounce is still a bounce.
    public static func respecting(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
