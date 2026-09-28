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
/// - **It can draw itself in.** With `drawIn`, the pen traces the outline first (the same
///   way the doodles draw), then the fill and the label arrive. Reduce Motion skips it.
///
/// The type names (`Sticker`, `.sticker`, `StickerButtonStyle`, `.stickerRoom()`) are
/// the ones twenty call sites already use, kept so the language changes in one file.
public struct Sticker: ViewModifier {
    private let fill: Color
    private let outline: Color
    private let corner: PenShape.Corner
    private let pressed: Bool
    /// Seconds to wait before tracing the outline in; nil draws it already finished.
    private let drawIn: Double?
    @State private var ink: CGFloat
    @State private var inked: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Nothing extends below a drawn shape any more. Kept for call sites that reserved it.
    public static let drop: CGFloat = 0
    public static let press: CGFloat = 0
    public static let line: CGFloat = Pen.line
    public static let lineThin: CGFloat = 1.2

    public init(fill: Color, outline: Color = .text, radius: CGFloat = Radius.card, pressed: Bool = false, drawIn: Double? = nil) {
        self.init(fill: fill, outline: outline, corner: .radius(radius), pressed: pressed, drawIn: drawIn)
    }

    public init(fill: Color, outline: Color = .text, corner: PenShape.Corner, pressed: Bool = false, drawIn: Double? = nil) {
        self.fill = fill
        self.outline = outline
        self.corner = corner
        self.pressed = pressed
        self.drawIn = drawIn
        _ink = State(initialValue: drawIn == nil ? 1 : 0)
        _inked = State(initialValue: drawIn == nil)
    }

    public func body(content: Content) -> some View {
        content
            .opacity(inked ? 1 : 0)
            .background {
                ZStack {
                    fillShape.fill(pressed ? pressedFill : fill)
                        .opacity(inked ? 1 : 0)
                    PenShape(corner)
                        .trim(from: 0, to: ink)
                        .stroke(outline, style: Ink.style(Pen.line))
                }
            }
            .scaleEffect(pressed ? 0.97 : 1)
            .onAppear {
                guard let drawIn, !inked else { return }
                if reduceMotion {
                    ink = 1
                    inked = true
                    return
                }
                withAnimation(.easeInOut(duration: 0.55).delay(drawIn)) { ink = 1 }
                withAnimation(.easeOut(duration: 0.25).delay(drawIn + 0.45)) { inked = true }
            }
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

    func sticker(fill: Color, outline: Color = .text, corner: PenShape.Corner, pressed: Bool = false, drawIn: Double? = nil) -> some View {
        modifier(Sticker(fill: fill, outline: outline, corner: corner, pressed: pressed, drawIn: drawIn))
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
    private let drawIn: Double?

    public init(fill: Color, outline: Color = .text, radius: CGFloat = Radius.card, drawIn: Double? = nil) {
        self.init(fill: fill, outline: outline, corner: .radius(radius), drawIn: drawIn)
    }

    public init(fill: Color, outline: Color = .text, corner: PenShape.Corner, drawIn: Double? = nil) {
        self.fill = fill
        self.outline = outline
        self.corner = corner
        self.drawIn = drawIn
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sticker(fill: fill, outline: outline, corner: corner, pressed: configuration.isPressed, drawIn: drawIn)
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

/// Press feedback for a whole written line on the page (a room, a row): the ink lightens
/// under the finger. No scale -- a full-width line that shrinks reads as a card.
public struct InkPressStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
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
