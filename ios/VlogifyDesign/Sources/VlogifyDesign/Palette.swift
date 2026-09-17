import SwiftUI

/// Vlogify's colors.
///
/// One rule governs every entry: **the chrome is cool white and the clips are the color.**
/// The whole app sits on a blue-white ground so a grid of twenty phone videos has nothing
/// to fight, and the doodles have a page to live on. There is no dark mode: the one
/// dark surface is the video itself, and the chrome drawn *over* video (the hour, the
/// pills on the camera) uses `ink` and `chalk` so it reads on any footage.
///
/// One accent. `blue` marks the single live action on any screen (the selected room
/// type, the create button, the ring around a recording).
///
/// Roles are declared in OKLCH rather than as hex literals because the text variants
/// are *derived* from the fills (see `OKLCH.readable(meeting:on:)`). In HSL that
/// derivation would shift hue and the readable blue would not look like the blue.
public enum Palette {

    // MARK: Ground

    /// The app. Cool blue-white, never pure white: pure white makes cards vanish.
    public static let ground = OKLCH(0.9729, 0.0029, 264)        // ~#F5F6F8
    /// Cards, sheets, text fields, the pill bar. One step up from ground — and the only
    /// pure white in the app, which is what makes a card read as a card.
    public static let card = OKLCH(1.0000, 0.0000, 264)          // #FFFFFF
    /// A selected pill, a pressed row. One step down from ground.
    public static let cardRaised = OKLCH(0.9300, 0.0120, 255)    // ~#E3E8F0
    /// Hairlines and card edges. Not a text color; never used for one.
    public static let hairline = OKLCH(0.9185, 0.0150, 251)      // ~#DDE5EE

    // MARK: Text

    /// Every word in the app, every outline, and the wordmark. A deep blue-slate rather
    /// than a black: it is the dominant colour of the whole design.
    public static let slate = OKLCH(0.2769, 0.0178, 227)         // ~#1F2A2F
    /// Secondary text: captions, "you + 2 friends", the time until the next ping.
    /// As light as it can be while clearing AA on ground, rather than slate at a
    /// guessed opacity.
    public static let slateSoft = slate.lightest(meeting: 4.5, on: ground)

    // MARK: Video chrome

    /// Behind a playing clip, and the pills drawn over the camera preview.
    public static let ink = OKLCH(0.1450, 0.0120, 250)
    /// Text over video.
    public static let chalk = OKLCH(0.9500, 0.0040, 255)
    public static let chalkSoft = chalk.darkest(meeting: 4.5, on: ink)

    // MARK: Accents

    /// The one live action: selection, the create check, the recording ring, and the
    /// bottom stop of every primary button's gradient.
    public static let blue = OKLCH(0.6321, 0.2018, 254)          // ~#0088FF
    /// The top stop of that gradient, and the fill of anything that has to carry text.
    public static let blueLight = OKLCH(0.7465, 0.1427, 243)     // ~#4DB6FF
    /// The two extruded shadow tiers under a blue button. Named because they are also
    /// what `Extruded` derives for every other fill; see `Extruded.tiers(under:)`.
    public static let blueMid = OKLCH(0.5498, 0.1756, 254)       // ~#0070D4
    public static let blueDeep = OKLCH(0.4817, 0.1528, 254)      // ~#005DB1
    /// The soft secondary.
    public static let periwinkle = OKLCH(0.7334, 0.1374, 263)    // ~#7AA7FF
    /// A missed slot, a denied permission — the one warm counterpoint. Muted on purpose:
    /// a missed hour is not an error, it is a life.
    public static let orange = OKLCH(0.7300, 0.1650, 42)         // ~#FB7F4C
    /// The mascot, the stars, the moon. The doodle color.
    public static let sand = OKLCH(0.7797, 0.1268, 60)           // ~#F2A35E
    /// Posted hour-dots and the "saved" line. Calm, not a button.
    public static let mint = OKLCH(0.8600, 0.1050, 166)          // ~#8AE7C1
    /// One more so a row of chips never repeats a colour.
    public static let lilac = OKLCH(0.7800, 0.1100, 305)         // ~#C8A5F0

    // MARK: Accent text

    /// Text-safe versions of the accents on ground, derived rather than picked.
    public static let blueInk = blue.readable(meeting: 4.5, on: ground)
    public static let orangeInk = orange.readable(meeting: 4.5, on: ground)
    public static let mintInk = mint.readable(meeting: 4.5, on: ground)
    public static let lilacInk = lilac.readable(meeting: 4.5, on: ground)

    /// Every accent that carries text on ground, for the contrast tests to iterate.
    public static let accentInks: [(name: String, color: OKLCH)] = [
        ("blue", blueInk), ("orange", orangeInk), ("mint", mintInk), ("lilac", lilacInk),
    ]

    // MARK: Playful fills

    /// A button fill and the colour of the words printed on it. Slate on anything light
    /// enough, white otherwise -- decided by contrast, not by eye, and tested.
    public struct Fill: Sendable, Identifiable {
        public let name: String
        public let color: OKLCH
        public var id: String { name }

        public var ink: OKLCH {
            Palette.slate.contrastRatio(against: color) >= Palette.card.contrastRatio(against: color)
                ? Palette.slate : Palette.card
        }

        /// The same hue as an opaque pastel, for big surfaces (room blocks). Opaque on
        /// purpose: a translucent fill lets the button's tiered shadow of the *content*
        /// show through as ghosted text.
        public var wash: OKLCH { OKLCH(0.93, 0.055, color.hue) }
    }

    /// The pool every playful thing draws from: chips, the tap burst, the outline picker.
    ///
    /// The blue here is `blueLight`, not `blue`. Pure #0088FF sits in the dead zone where
    /// neither slate (4.17) nor white (3.52) clears AA, so it cannot be a fill that
    /// carries a label -- it stays the action colour, where its own button style supplies
    /// a white label and a text shadow over a gradient.
    public static let playful: [Fill] = [
        Fill(name: "blue", color: blueLight), Fill(name: "periwinkle", color: periwinkle),
        Fill(name: "orange", color: orange), Fill(name: "sand", color: sand),
        Fill(name: "mint", color: mint), Fill(name: "lilac", color: lilac),
        Fill(name: "slate", color: slate),
    ]

    /// Deterministic pick, so a chip keeps its colour across launches.
    public static func playful(index: Int) -> Fill {
        playful[((index % playful.count) + playful.count) % playful.count]
    }

    /// Twelve avatar discs, one per `avatarSeed % 12`. Evenly spaced hues at one
    /// lightness so no member's disc is louder than another's.
    ///
    /// Untouched by the folk palette on purpose: the seed rides on `Profile.avatarSeed`
    /// over the wire, so remapping these hues would change the colour every existing
    /// member already thinks of as theirs.
    public static func avatar(seed: Int) -> OKLCH {
        OKLCH(0.7200, 0.1200, Double((seed % 12) * 30))
    }
}

public extension Color {
    // Semantic roles. Views use these; the raw names above stay in the design package.
    static let ground = Color(Palette.ground)
    static let card = Color(Palette.card)
    static let cardRaised = Color(Palette.cardRaised)
    static let hairline = Color(Palette.hairline)
    static let text = Color(Palette.slate)
    static let textSoft = Color(Palette.slateSoft)

    /// What a colour *means*, so call sites stop reaching for a hue by name.
    static let action = Color(Palette.blue)
    static let actionInk = Color(Palette.blueInk)
    static let warn = Color(Palette.orange)
    static let warnInk = Color(Palette.orangeInk)
    static let good = Color(Palette.mint)
    static let goodInk = Color(Palette.mintInk)

    static let slate = Color(Palette.slate)
    static let slateSoft = Color(Palette.slateSoft)
    static let ink = Color(Palette.ink)
    static let chalk = Color(Palette.chalk)
    static let chalkSoft = Color(Palette.chalkSoft)
    // No `Color.blue`: it would shadow SwiftUI's own. The action blue is `.action`.
    static let blueLight = Color(Palette.blueLight)
    static let blueMid = Color(Palette.blueMid)
    static let blueDeep = Color(Palette.blueDeep)
    static let periwinkle = Color(Palette.periwinkle)
    static let sand = Color(Palette.sand)
    static let lilac = Color(Palette.lilac)
    static let lilacInk = Color(Palette.lilacInk)

    static func avatar(seed: Int) -> Color { Color(Palette.avatar(seed: seed)) }
}
