import SwiftUI

extension View {
    /// Names a screen or container for the UI walker.
    ///
    /// `.accessibilityIdentifier` on a bare stack is applied to every child, which
    /// silently overwrites the buttons' own identifiers -- the walker then cannot
    /// find `permissions.continue` because it is called `screen.permissions`. Making
    /// the container an element that *contains* its children keeps the name on the
    /// container and the children's names on the children.
    func screen(_ id: String) -> some View {
        accessibilityElement(children: .contain)
            .accessibilityIdentifier(id)
    }
}
