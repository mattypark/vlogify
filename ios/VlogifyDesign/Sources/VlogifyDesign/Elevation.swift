import SwiftUI

/// Shadow recipes by height, for the few surfaces that are not stickers.
///
/// Not one shadow reused. A resting card and a sheet over everything are at different
/// heights, and a single shadow flattens both into the same plane. Each tier scales blur
/// and offset together, because a shadow whose blur grows without its offset reads as a
/// glow. Stickers never use these: their shadow is hard and belongs to the outline.
public struct Elevation: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let y: CGFloat

    /// Resting on the page — a note block with focus, a clip tile.
    public static let low = Elevation(color: Color.text.opacity(0.08), radius: 6, y: 2)
    /// A card the user is meant to read as an object they could pick up.
    public static let card = Elevation(color: Color.text.opacity(0.14), radius: 16, y: 8)
    /// A sheet over everything else.
    public static let sheet = Elevation(color: Color.text.opacity(0.16), radius: 28, y: 14)
}

public extension View {
    /// Apply an elevation. One call, so a shadow can never be half-specified.
    func elevated(_ level: Elevation) -> some View {
        shadow(color: level.color, radius: level.radius, x: 0, y: level.y)
    }
}
