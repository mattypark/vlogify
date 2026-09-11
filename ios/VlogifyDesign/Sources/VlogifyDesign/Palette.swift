import SwiftUI

/// Vlogify's colors.
///
/// One rule governs every entry: **the chrome is paper and the clips are the color.**
/// The whole app sits on warm off-white so a grid of twenty phone videos has nothing
/// to fight, and the doodles have a page to live on. There is no dark mode: the one
/// dark surface is the video itself, and the chrome drawn *over* video (the hour, the
/// pills on the camera) uses `ink` and `chalk` so it reads on any footage.
///
/// One accent. Orchid marks the single live action on any screen (the selected room
/// type, the create button, the ring around a recording).
///
/// Roles are declared in OKLCH rather than as hex literals because the text variants
/// are *derived* from the fills (see `OKLCH.readable(meeting:on:)`). In HSL that
/// derivation would shift hue and the readable orchid would not look like the orchid.
public enum Palette {

    // MARK: Ground

    /// The app. Warm off-white, never pure white: pure white makes cards vanish.
    public static let paper = OKLCH(0.9700, 0.0030, 90)          // ~#F5F5F3
    /// Cards, sheets, text fields, the pill bar. One step up from paper.
    public static let card = OKLCH(0.9960, 0.0020, 90)           // ~#FEFEFD
    /// A selected pill, a pressed row. One step down from paper.
    public static let cardRaised = OKLCH(0.9200, 0.0060, 90)     // ~#E8E7E3
    /// Hairlines and card edges. Not a text color; never used for one.
    public static let hairline = OKLCH(0.8700, 0.0050, 90)

    // MARK: Text

    /// Every word in the app, and the wordmark.
    public static let soot = OKLCH(0.2000, 0.0030, 280)          // ~#1A1A1D
    /// Secondary text: captions, "you + 2 friends", the time until the next ping.
    /// As light as it can be while clearing AA on paper, rather than soot at a
    /// guessed opacity.
    public static let sootSoft = soot.lightest(meeting: 4.5, on: paper)

    // MARK: Video chrome

    /// Behind a playing clip, and the pills drawn over the camera preview.
    public static let ink = OKLCH(0.1450, 0.0030, 280)           // ~#0C0C0E
    /// Text over video.
    public static let chalk = OKLCH(0.9500, 0.0030, 90)          // ~#EFEFED
    public static let chalkSoft = chalk.darkest(meeting: 4.5, on: ink)

    // MARK: Accents

    /// The one live action: selection, the create check, the recording ring.
    public static let orchid = OKLCH(0.7500, 0.1700, 330)        // ~#E58BE8
    /// The shutter. A smiley you press.
    public static let sky = OKLCH(0.8000, 0.1200, 230)           // ~#5AC8FA
    /// The mascot, the stars, the moon. The doodle color.
    public static let butter = OKLCH(0.9300, 0.0900, 95)         // ~#F7E9A4
    /// A missed slot, a denied permission. Muted on purpose: a missed hour is not an
    /// error, it is a life.
    public static let ember = OKLCH(0.7000, 0.1500, 35)          // ~#F08A5B
    /// Posted hour-dots and the "saved" line. Calm, not a button.
    public static let spearmint = OKLCH(0.8500, 0.1100, 175)     // ~#6FE0C6

    // MARK: Accent text

    /// Text-safe versions of the accents on paper, derived rather than picked.
    public static let orchidInk = orchid.readable(meeting: 4.5, on: paper)
    public static let skyInk = sky.readable(meeting: 4.5, on: paper)
    public static let emberInk = ember.readable(meeting: 4.5, on: paper)
    public static let spearmintInk = spearmint.readable(meeting: 4.5, on: paper)

    /// Every accent that carries text on paper, for the contrast tests to iterate.
    public static let accentInks: [(name: String, color: OKLCH)] = [
        ("orchid", orchidInk), ("sky", skyInk), ("ember", emberInk), ("spearmint", spearmintInk),
    ]

    /// Twelve avatar discs, one per `avatarSeed % 12`. Evenly spaced hues at one
    /// lightness so no member's disc is louder than another's.
    public static func avatar(seed: Int) -> OKLCH {
        OKLCH(0.7200, 0.1200, Double((seed % 12) * 30))
    }
}

public extension Color {
    // Semantic roles. Views use these; the raw names above stay in the design package.
    static let ground = Color(Palette.paper)
    static let card = Color(Palette.card)
    static let cardRaised = Color(Palette.cardRaised)
    static let hairline = Color(Palette.hairline)
    static let text = Color(Palette.soot)
    static let textSoft = Color(Palette.sootSoft)

    static let paper = Color(Palette.paper)
    static let soot = Color(Palette.soot)
    static let sootSoft = Color(Palette.sootSoft)
    static let ink = Color(Palette.ink)
    static let chalk = Color(Palette.chalk)
    static let chalkSoft = Color(Palette.chalkSoft)
    static let orchid = Color(Palette.orchid)
    static let orchidInk = Color(Palette.orchidInk)
    static let sky = Color(Palette.sky)
    static let skyInk = Color(Palette.skyInk)
    static let butter = Color(Palette.butter)
    static let ember = Color(Palette.ember)
    static let emberInk = Color(Palette.emberInk)
    static let spearmint = Color(Palette.spearmint)
    static let spearmintInk = Color(Palette.spearmintInk)

    static func avatar(seed: Int) -> Color { Color(Palette.avatar(seed: seed)) }
}
