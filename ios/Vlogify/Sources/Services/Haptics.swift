import UIKit

/// A vocabulary, not a garnish: three feels, each meaning one thing.
@MainActor
enum Haptics {
    /// A pill selected, a toggle flipped.
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// The shutter. The one heavy tap in the app.
    static func shutter() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    /// A clip posted, a room created.
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
