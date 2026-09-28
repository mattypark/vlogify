import SwiftUI

/// The drawn language: every pressable thing is outlined by hand.
///
/// - **A pen line, not a border.** The outline is a `PenShape`: it wobbles, it does not
///   quite close, and the pen runs past where it started. No plinth, no gloss, no shadow
///   -- a page has no light source.
/// - **Paper inside.** Most things are filled with the page, so the line is the object.
///   The one primary action on a screen is filled solid with the pen.
/// - **Press is a pencil wash.** A pressed paper thing takes the fog fill and shrinks a
///   hair, like a finger pushing into paper. A pressed pen thing lightens.
///
/// The type names (`Sticker`, `.sticker`, `StickerButtonStyle`, `.stickerRoom()`) are
/// the ones twenty call sites already use, kept so the language changes in one file.
public struct Sticker: ViewModifier {
    private let fill: Color
    private let outline: Color
    private let corner: PenShape.Corner
    private let pressed: Bool

    /// Nothing extends below a drawn shape any more. Kept for call sites that reserved it.
    public static let drop: CGFloat = 0
    public static let press: CGFloat = 0
    public static let line: CGFloat = Pen.line
    public static let lineThin: CGFloat = 1.2

    public init(fill: Color, outline: Color = .text, radius: CGFloat = Radius.card, pressed: Bool = false) {
        self.init(fill: fill, outline: outline, corner: .radius(radius), pressed: pressed)
    }

    public init(fill: Color, outline: Color = .text, corner: PenShape.Corner, pressed: Bool = false) {
        self.fill = fill
        self.outline = outline
        self.corner = corner
        self.pressed = pressed
    }

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    fillShape.fill(pressed ? pressedFill : fill)
                    PenShape(corner).stroke(outline, style: Ink.style(Pen.line))
                }
            }
            .scaleEffect(pressed ? 0.97 : 1)
    }

    /// The fill sits just inside the ideal edge so the wobbling line always covers it.
    private var fillShape: AnyShape {
        switch corner {
        case .radius(let r): AnyShape(RoundedRectangle(cornerRadius: r, style: .continuous).inset(by: Pen.wobble))
        case .capsule: AnyShape(Capsule().inset(by: Pen.wobble))
        case .circle: AnyShape(Ellipse().inset(by: Pen.wobble))
        }
    }

    private var pressedFill: Color {
        fill == .text || fill == .action ? Color.text.opacity(0.82) : .fog
    }
}

public extension View {
    func sticker(fill: Color, outline: Color = .text, radius: CGFloat = Radius.card, pressed: Bool = false) -> some View {
        modifier(Sticker(fill: fill, outline: outline, radius: radius, pressed: pressed))
    }

    func sticker(fill: Color, outline: Color = .text, corner: PenShape.Corner, pressed: Bool = false) -> some View {
        modifier(Sticker(fill: fill, outline: outline, corner: corner, pressed: pressed))
    }

    /// Room for the wobble at a screen edge: the pen can stray a point and a half.
    func stickerRoom() -> some View {
        padding(Pen.wobble)
    }
}

/// A drawn button.
public struct StickerButtonStyle: ButtonStyle {
    private let fill: Color
    private let outline: Color
    private let corner: PenShape.Corner

    public init(fill: Color, outline: Color = .text, radius: CGFloat = Radius.card) {
        self.init(fill: fill, outline: outline, corner: .radius(radius))
    }

    public init(fill: Color, outline: Color = .text, corner: PenShape.Corner) {
        self.fill = fill
        self.outline = outline
        self.corner = corner
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sticker(fill: fill, outline: outline, corner: corner, pressed: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A drawn circle button -- same rules, round.
public struct StickerCircleStyle: ButtonStyle {
    private let fill: Color
    private let outline: Color

    public init(fill: Color, outline: Color = .text) {
        self.fill = fill
        self.outline = outline
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sticker(fill: fill, outline: outline, corner: .circle, pressed: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Press physics for bare glyphs sitting inside something else.
public struct SquashButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}
