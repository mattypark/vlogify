import SwiftUI

/// A 4pt base. Screen gutters are 20.
///
/// The reason this file exists at all: every generated interface converges on the
/// same look, and the mechanism is always one spacing value used everywhere and one
/// corner radius on everything. A closed set forces a decision per gap.
public enum Space {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let gutter: CGFloat = 20
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

/// Radius tracks size. A pill is a pill; a tile is 12; a sheet is 20; the big
/// room-type cards are 28 because they are the largest object on that screen. Past
/// ~16 a row stops reading as a row and starts reading as a blob, which is the single
/// most common tell of a generated interface -- so rows stay at 12.
public enum Radius {
    public static let tile: CGFloat = 12
    public static let row: CGFloat = 12
    public static let sheet: CGFloat = 20
    public static let card: CGFloat = 28
    public static let frame: CGFloat = 32
    public static let pill: CGFloat = 999
}

/// Fixed sizes for the objects the app is built around.
public enum Metrics {
    /// Apple's minimum, and the size of every bar button.
    public static let hitTarget: CGFloat = 44
    /// The bottom bar's round buttons.
    public static let barButton: CGFloat = 56
    /// The smiley shutter.
    public static let shutter: CGFloat = 84
    /// A member tile in the room timeline.
    public static let tileHeight: CGFloat = 132
    /// A hour-dot on a room card.
    public static let hourDot: CGFloat = 6
    /// An avatar disc in a members row.
    public static let avatar: CGFloat = 32
}

public extension View {
    /// Pads the tappable area to Apple's minimum without changing the drawn size.
    func hitTarget() -> some View {
        frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
    }
}
