import SwiftUI

/// Vlogify's colors: ink on paper.
///
/// One rule governs every entry: **the chrome is a page and the clips are the color.**
/// The app is black pen on white paper, the way a sketchbook is, so a grid of twenty
/// phone videos is the only colour on screen and the doodles have a page to live on.
/// There is no dark mode: the one dark surface is the video itself, and the chrome
/// drawn *over* video (the hour, the pills on the camera) uses `ink` and `chalk` so it
/// reads on any footage.
///
/// One colour that is not ink: `red`, and only where it means something -- a recording
/// in progress, a destructive action. Nothing is decorated with it.
///
/// Roles are declared in OKLCH so the derived text roles (`lightest(meeting:on:)`) come
/// out of the same model the rest of the package measures contrast in.
public enum Palette {

    // MARK: Paper

    /// The page. Pure white: on a black-pen design a tinted ground reads as a stain.
    public static let ground = OKLCH(1.0000, 0.0000, 0)          // #FFFFFF
    /// Cards, sheets, fields. The same paper -- a card is an outline, not a fill.
    public static let card = OKLCH(1.0000, 0.0000, 0)            // #FFFFFF
    /// A pressed or picked thing: the page with a pencil wash on it.
    public static let fog = OKLCH(0.9560, 0.0020, 90)            // ~#F1F1EE
    /// Dividers. Not a text colour; never used for one.
    public static let hairline = OKLCH(0.9050, 0.0020, 90)       // ~#E1E1DD

    // MARK: Ink

    /// Every word, every outline, every doodle, the wordmark. Soft black, never #000:
    /// pure black next to pure white vibrates at body sizes.
    public static let pen = OKLCH(0.1776, 0.0000, 0)             // #111111
    /// Secondary text: captions, "you + 2 friends", the time until the next nudge. As
    /// light as it can be while clearing AA on paper, rather than pen at a guessed opacity.
    public static let penSoft = pen.lightest(meeting: 4.5, on: ground)

    // MARK: Video chrome

    /// Behind a playing clip, and the pills drawn over the camera preview.
    public static let ink = OKLCH(0.1450, 0.0000, 0)
    /// Text over video.
    public static let chalk = OKLCH(0.9700, 0.0000, 0)
    public static let chalkSoft = chalk.darkest(meeting: 4.5, on: ink)

    // MARK: Meaning

    /// Recording, delete, a denied permission. The only colour in the chrome.
    public static let red = OKLCH(0.6280, 0.2100, 27)            // ~#E5484D
    public static let redInk = red.readable(meeting: 4.5, on: ground)

    /// Every non-pen role that carries text on paper, for the contrast tests to iterate.
    public static let accentInks: [(name: String, color: OKLCH)] = [
        ("red", redInk), ("penSoft", penSoft),
    ]

    // MARK: Fills

    /// A button fill and the colour of the words printed on it, chosen by contrast.
    public struct Fill: Sendable, Identifiable {
        public let name: String
        public let color: OKLCH
        public var id: String { name }

        public var ink: OKLCH {
            Palette.pen.contrastRatio(against: color) >= Palette.card.contrastRatio(against: color)
                ? Palette.pen : Palette.card
        }

        /// What a big surface of this fill looks like. On paper, that is paper.
        public var wash: OKLCH { color.lightness > 0.5 ? color : Palette.fog }
    }

    /// The fills a pressable thing can have: paper (most things), a pencil wash (picked),
    /// and solid pen (the one primary action on a screen).
    public static let fills: [Fill] = [
        Fill(name: "paper", color: card), Fill(name: "fog", color: fog), Fill(name: "pen", color: pen),
    ]

    /// Deterministic pick, so a thing keeps its fill across launches.
    public static func fill(index: Int) -> Fill {
        fills[((index % fills.count) + fills.count) % fills.count]
    }

    /// Twelve hues, one per `avatarSeed % 12`. No longer drawn -- the mark replaced the
    /// coloured disc -- but the seed still rides on `Profile.avatarSeed` over the wire and
    /// older builds still paint with it, so these hues are never remapped.
    public static func avatar(seed: Int) -> OKLCH {
        OKLCH(0.7200, 0.1200, Double((seed % 12) * 30))
    }
}

public extension Color {
    // Semantic roles. Views use these; the raw names above stay in the design package.
    static let ground = Color(Palette.ground)
    static let card = Color(Palette.card)
    static let cardRaised = Color(Palette.fog)
    static let fog = Color(Palette.fog)
    static let hairline = Color(Palette.hairline)
    static let text = Color(Palette.pen)
    static let textSoft = Color(Palette.penSoft)

    /// What a colour *means*, so call sites stop reaching for a hue by name. On paper the
    /// live action is simply the pen: a filled black shape is the loudest thing on a page.
    static let action = Color(Palette.pen)
    static let actionInk = Color(Palette.pen)
    static let warn = Color(Palette.red)
    static let warnInk = Color(Palette.redInk)
    static let recording = Color(Palette.red)
    static let good = Color(Palette.pen)
    static let goodInk = Color(Palette.pen)

    static let pen = Color(Palette.pen)
    static let ink = Color(Palette.ink)
    static let chalk = Color(Palette.chalk)
    static let chalkSoft = Color(Palette.chalkSoft)

    static func avatar(seed: Int) -> Color { Color(Palette.avatar(seed: seed)) }
}
