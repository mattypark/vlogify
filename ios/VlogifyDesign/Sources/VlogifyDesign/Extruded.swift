import SwiftUI

/// The extruded language, taken from folk.
///
/// - **A tiered plinth, not a hard black offset.** A pressable thing sits on two tiers of
///   progressively darker shades *of its own fill*, plus a soft ambient shadow underneath.
///   The old chingo sticker dropped one hard soot block down-and-right; that read as
///   printed-and-stuck-down, and it was the loudest thing tying vlogify to another app.
/// - **Down, never sideways.** The plinth only extends below. A diagonal offset reads as a
///   sticker; a vertical one reads as a key you can push.
/// - **A gloss on the top edge.** One bright line where the light lands, which is what
///   turns a flat rectangle into something with a lid.
/// - **Thick outlines.** 3pt, in slate — folk's `--border: 3px solid var(--ink)`.
/// - **Press compresses the plinth.** The block travels down by `press` and the tiers
///   collapse to one, so the bottom edge stays put and only the lid moves. Never scale it:
///   scaling slides the plinth out from under the lid.
public struct Sticker: ViewModifier {
    private let fill: Color
    private let outline: Color
    private let shape: AnyShape
    private let pressed: Bool

    /// How far the plinth extends below the lid at rest. One value everywhere; it is also
    /// what `stickerRoom()` reserves.
    public static let drop: CGFloat = 4
    /// How far the lid travels on press. One less than `drop`, so a single tier is still
    /// visible and the button never looks like it fell through the page.
    public static let press: CGFloat = 3
    public static let line: CGFloat = 3
    /// folk's `--border-2`. For borders inside an already-bordered block, where the full
    /// 3pt would read as a second frame.
    public static let lineThin: CGFloat = 2

    /// How much slate is mixed into the fill for each tier. Applied to folk's own
    /// `#0088FF` these land within a couple of points of their `#0070D4` / `#005DB1`, so
    /// every other fill gets the same relationship for free rather than a hardcoded blue.
    private static let midMix = 0.22
    private static let deepMix = 0.38

    public init(fill: Color, outline: Color = .text, radius: CGFloat = Radius.card, pressed: Bool = false) {
        self.init(fill: fill,
                  outline: outline,
                  shape: AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous)),
                  pressed: pressed)
    }

    public init(fill: Color, outline: Color = .text, shape: AnyShape, pressed: Bool = false) {
        self.fill = fill
        self.outline = outline
        self.shape = shape
        self.pressed = pressed
    }

    public func body(content: Content) -> some View {
        content
            .background { plinth }
            .offset(y: pressed ? Self.press : 0)
    }

    private var plinth: some View {
        ZStack {
            shape.fill(Color.text.opacity(Self.deepMix))
                .background { shape.fill(fill) }
                .offset(y: pressed ? Self.press : Self.drop)
            shape.fill(Color.text.opacity(Self.midMix))
                .background { shape.fill(fill) }
                .offset(y: pressed ? Self.press : Self.drop / 2)
            shape.fill(fill)
                .overlay { shape.fill(Self.gloss) }
                .overlay { shape.stroke(outline, lineWidth: Self.line * 2).clipShape(shape) }
        }
        // Without this SwiftUI shadows each sub-layer separately and the tiers double up.
        .compositingGroup()
        .shadow(color: Color.text.opacity(pressed ? 0.14 : 0.26),
                radius: pressed ? 4 : 10,
                y: pressed ? 2 : 7)
    }

    /// The lid's lighting, in one layer: a bright hairline where the top edge catches the
    /// light, falling away to nothing by the middle. This is also what stands in for folk's
    /// two-stop fill gradient — the top of the button is simply lighter than the bottom.
    private static let gloss = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.42), location: 0.00),
            .init(color: .white.opacity(0.14), location: 0.10),
            .init(color: .white.opacity(0.00), location: 0.62),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

public extension View {
    func sticker(fill: Color, outline: Color = .text, radius: CGFloat = Radius.card, pressed: Bool = false) -> some View {
        modifier(Sticker(fill: fill, outline: outline, radius: radius, pressed: pressed))
    }

    func sticker(fill: Color, outline: Color = .text, shape: AnyShape, pressed: Bool = false) -> some View {
        modifier(Sticker(fill: fill, outline: outline, shape: shape, pressed: pressed))
    }

    /// The plinth lives below the frame; call sites at a screen edge pad for it.
    /// Bottom only — the extrusion has no sideways component.
    func stickerRoom() -> some View {
        padding(.bottom, Sticker.drop)
    }
}

/// A button that behaves like a key: it compresses its own plinth.
public struct StickerButtonStyle: ButtonStyle {
    private let fill: Color
    private let outline: Color
    private let radius: CGFloat

    public init(fill: Color, outline: Color = .text, radius: CGFloat = Radius.card) {
        self.fill = fill
        self.outline = outline
        self.radius = radius
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sticker(fill: fill, outline: outline, radius: radius, pressed: configuration.isPressed)
            // folk's own .12s cubic-bezier(.22,1,.36,1): fast out, no overshoot. A spring
            // would make the lid wobble after landing, and a key does not wobble.
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A circular key — same rules, round.
public struct StickerCircleStyle: ButtonStyle {
    private let fill: Color
    private let outline: Color

    public init(fill: Color, outline: Color = .text) {
        self.fill = fill
        self.outline = outline
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sticker(fill: fill, outline: outline, shape: AnyShape(Circle()), pressed: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Press physics for bare glyphs sitting inside something else. Never on an extruded
/// block: scaling one slides the plinth out from under the lid.
public struct SquashButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}
