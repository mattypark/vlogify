import SwiftUI

/// The sticker language, borrowed from chingo.
///
/// - **Hard shadows, zero blur.** A blurred shadow says "floating pane". A hard offset says
///   "a thing printed and stuck down", which is what a fat rounded letterform looks like.
/// - **Thick outlines.** 3pt, in soot.
/// - **Flat fills.** No gradients on components.
/// - **Press sinks into the shadow.** The block moves down-right by exactly its shadow offset
///   and the shadow disappears, so pressing looks like actually pressing something down
///   rather than dimming it.
public struct Sticker: ViewModifier {
    private let fill: Color
    private let outline: Color
    private let radius: CGFloat
    private let pressed: Bool

    /// How far the shadow sits down and right. One value everywhere.
    public static let drop: CGFloat = 4
    public static let line: CGFloat = 3

    public init(fill: Color, outline: Color = .soot, radius: CGFloat = Radius.card, pressed: Bool = false) {
        self.fill = fill
        self.outline = outline
        self.radius = radius
        self.pressed = pressed
    }

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(outline, lineWidth: Self.line)
            }
            // Without this SwiftUI shadows each sub-layer separately and the outline draws
            // twice.
            .compositingGroup()
            // radius: 0 is the whole point. SwiftUI's shadow blurs by default and a blurred
            // version of this reads as an ordinary card with a heavy border.
            .shadow(color: pressed ? .clear : outline, radius: 0,
                    x: pressed ? 0 : Self.drop, y: pressed ? 0 : Self.drop)
            .offset(x: pressed ? Self.drop : 0, y: pressed ? Self.drop : 0)
    }
}

public extension View {
    func sticker(fill: Color, outline: Color = .soot, radius: CGFloat = Radius.card, pressed: Bool = false) -> some View {
        modifier(Sticker(fill: fill, outline: outline, radius: radius, pressed: pressed))
    }

    /// The shadow lives outside the frame; call sites at a screen edge pad for it.
    func stickerRoom() -> some View {
        padding(.trailing, Sticker.drop).padding(.bottom, Sticker.drop)
    }
}

/// A button that behaves like a sticker: it sinks into its own shadow.
///
/// Scaling a block that has a hard offset shadow makes the shadow slide out from under it,
/// which looks like a bug; moving it into the shadow is the motion the shape is asking for.
public struct StickerButtonStyle: ButtonStyle {
    private let fill: Color
    private let outline: Color
    private let radius: CGFloat

    public init(fill: Color, outline: Color = .soot, radius: CGFloat = Radius.card) {
        self.fill = fill
        self.outline = outline
        self.radius = radius
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sticker(fill: fill, outline: outline, radius: radius, pressed: configuration.isPressed)
            // Fast and flat. A spring here would make the block wobble after landing, and a
            // printed thing does not wobble.
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

/// A circular sticker — same rules, round.
public struct StickerCircleStyle: ButtonStyle {
    private let fill: Color
    private let outline: Color

    public init(fill: Color, outline: Color = .soot) {
        self.fill = fill
        self.outline = outline
    }

    public func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        return configuration.label
            .background { Circle().fill(fill) }
            .overlay { Circle().strokeBorder(outline, lineWidth: Sticker.line) }
            .compositingGroup()
            .shadow(color: down ? .clear : outline, radius: 0,
                    x: down ? 0 : Sticker.drop, y: down ? 0 : Sticker.drop)
            .offset(x: down ? Sticker.drop : 0, y: down ? Sticker.drop : 0)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

/// Press physics for bare glyphs sitting inside something else. Never on a sticker:
/// scaling a hard-shadowed block slides the shadow out from under it.
public struct SquashButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}
