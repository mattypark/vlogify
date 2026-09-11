import SwiftUI

/// Every animation in Vlogify, named.
///
/// Springs rather than duration curves: a clip landing on the timeline is a physical
/// event and a cubic ease reads as a screen updating rather than as a moment arriving.
/// Exits are always faster than entrances; an exit that lingers reads as a bug.
public enum Motion {
    /// A control acknowledging a tap. Fast, almost no bounce.
    public static let tap = Animation.spring(duration: 0.22, bounce: 0.15)
    /// A clip landing in its tile, a room card appearing, a note block arriving.
    public static let land = Animation.spring(duration: 0.42, bounce: 0.22)
    /// Something arriving with a little joy: a burst, a block popping in.
    public static let pop = Animation.spring(duration: 0.55, bounce: 0.34)
    /// Sheets, the plus menu, anything structural.
    public static let shift = Animation.spring(duration: 0.34, bounce: 0.1)
    /// Something leaving. Always faster than its arrival.
    public static let dismiss = Animation.spring(duration: 0.26, bounce: 0)
    /// The two-second recording ring. Linear on purpose: it is a clock.
    public static let ring = Animation.linear(duration: 2)

    /// The wind-up before a payoff, the payoff, the settle.
    public static let anticipate = Animation.spring(duration: 0.30, bounce: 0)
    public static let impact = Animation.spring(duration: 0.50, bounce: 0.52)
    public static let settle = Animation.spring(duration: 0.70, bounce: 0.10)

    /// Honors Reduce Motion by dropping the spring, not the state change.
    ///
    /// Returning `nil` rather than a fast spring is deliberate: the setting means "do
    /// not move things", and a 60ms bounce is still a bounce.
    public static func respecting(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    @MainActor
    public static var reduceMotion: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }
}

/// Squash → stretch → settle. The oldest trick there is, and the whole difference between
/// a drawn thing that is alive and a PNG being moved. Used for exactly three moments:
/// a clip posted, a room created, a day saved.
public enum RewardPhase: CaseIterable {
    case rest, anticipate, impact, settle

    public var scale: CGFloat {
        switch self {
        case .rest: 1.0
        case .anticipate: 0.88
        case .impact: 1.18
        case .settle: 1.0
        }
    }

    public var animation: Animation {
        switch self {
        case .rest: Motion.settle
        case .anticipate: Motion.anticipate
        case .impact: Motion.impact
        case .settle: Motion.settle
        }
    }
}

public extension View {
    func rewardBeat<T: Equatable>(on trigger: T) -> some View {
        phaseAnimator(RewardPhase.allCases, trigger: trigger) { view, phase in
            view.scaleEffect(phase.scale)
        } animation: { phase in
            phase.animation
        }
    }
}
