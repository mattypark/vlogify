import SwiftUI

/// Vlogify's colors.
///
/// One rule governs every entry: **the chrome is ink and the clips are the color.**
/// The app is near-black so a grid of twenty phone videos has nothing to fight. The
/// welcome screen is the one paper surface -- the doodles need a page to sit on -- and
/// after sign-in the app never shows it again.
///
/// One accent. Orchid marks the single live action on any screen (the selected room
/// type, the create button, the ring around a recording). Mint is the wordmark and
/// nothing else, so the logo never reads as a button.
///
/// Roles are declared in OKLCH rather than as hex literals because the text variants
/// are *derived* from the fills (see `OKLCH.lightest(meeting:on:)`). In HSL that
/// derivation would shift hue and the readable orchid would not look like the orchid.
public enum Palette {

    // MARK: Ground

    /// The app. Not #000: pure black makes the raised surfaces look like holes, and a
    /// hair of warmth keeps OLED smear off the tile edges.
    public static let ink = OKLCH(0.1450, 0.0030, 280)          // ~#0C0C0E
    /// The welcome page.
    public static let paper = OKLCH(0.9700, 0.0030, 90)         // ~#F5F5F3
    /// Cards, sheets, the pill bar. One step up from ink.
    public static let surface = OKLCH(0.2200, 0.0030, 280)      // ~#1E1E21
    /// A selected pill, a pressed row. Two steps up.
    public static let surfaceRaised = OKLCH(0.2900, 0.0030, 280) // ~#2E2E32
    /// Hairlines. Not a text color; never used for one.
    public static let line = OKLCH(0.3400, 0.0030, 280)

    // MARK: Ink on ink

    /// Every word in the dark app.
    public static let chalk = OKLCH(0.9500, 0.0030, 90)         // ~#EFEFED
    /// Secondary text: captions, "you + 2 friends", the time until the next ping.
    /// As dim as it can be while clearing AA on ink, rather than chalk at a guessed
    /// opacity.
    public static let chalkSoft = OKLCH(0.9500, 0.0030, 90).darkest(meeting: 4.5, on: ink)
    /// Every word on the welcome page.
    public static let soot = OKLCH(0.2000, 0.0030, 280)         // ~#1A1A1D
    public static let sootSoft = soot.lightest(meeting: 4.5, on: paper)

    // MARK: Accents

    /// The one live action: selection, the create check, the recording ring.
    public static let orchid = OKLCH(0.7500, 0.1700, 330)       // ~#E58BE8
    /// The wordmark. Only the wordmark.
    public static let spearmint = OKLCH(0.8500, 0.1100, 175)         // ~#6FE0C6
    /// The shutter. A smiley you press.
    public static let sky = OKLCH(0.8000, 0.1200, 230)          // ~#5AC8FA
    /// The mascot, the stars, the moon. The doodle color.
    public static let butter = OKLCH(0.9300, 0.0900, 95)        // ~#F7E9A4
    /// A missed slot, a denied permission. Muted on purpose: a missed hour is not an
    /// error, it is a life.
    public static let ember = OKLCH(0.7000, 0.1500, 35)         // ~#F08A5B

    // MARK: Accent text

    /// Text-safe versions of the accents on ink, derived rather than picked.
    public static let orchidInk = orchid.readable(meeting: 4.5, on: ink)
    public static let spearmintInk = spearmint.readable(meeting: 4.5, on: ink)
    public static let skyInk = sky.readable(meeting: 4.5, on: ink)
    public static let emberInk = ember.readable(meeting: 4.5, on: ink)

    /// Every accent that carries text on ink, for the contrast tests to iterate.
    public static let accentInks: [(name: String, color: OKLCH)] = [
        ("orchid", orchidInk), ("spearmint", spearmintInk), ("sky", skyInk), ("ember", emberInk),
    ]

    /// Twelve avatar discs, one per `avatarSeed % 12`. Evenly spaced hues at one
    /// lightness so no member's disc is louder than another's.
    public static func avatar(seed: Int) -> OKLCH {
        OKLCH(0.7200, 0.1200, Double((seed % 12) * 30))
    }
}

public extension Color {
    static let ink = Color(Palette.ink)
    static let paper = Color(Palette.paper)
    static let surface = Color(Palette.surface)
    static let surfaceRaised = Color(Palette.surfaceRaised)
    static let line = Color(Palette.line)
    static let chalk = Color(Palette.chalk)
    static let chalkSoft = Color(Palette.chalkSoft)
    static let soot = Color(Palette.soot)
    static let sootSoft = Color(Palette.sootSoft)
    static let orchid = Color(Palette.orchid)
    static let orchidInk = Color(Palette.orchidInk)
    static let spearmint = Color(Palette.spearmint)
    static let spearmintInk = Color(Palette.spearmintInk)
    static let sky = Color(Palette.sky)
    static let skyInk = Color(Palette.skyInk)
    static let butter = Color(Palette.butter)
    static let ember = Color(Palette.ember)
    static let emberInk = Color(Palette.emberInk)

    static func avatar(seed: Int) -> Color { Color(Palette.avatar(seed: seed)) }
}
