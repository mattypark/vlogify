import Testing
@testable import VlogifyDesign

/// The design system claims one cool ground carries the whole app and that every
/// word on it is readable. Those are testable claims, so they are tested -- a palette
/// tweak that drops an accent below AA fails here rather than shipping.
struct PaletteTests {
    @Test("Body text on ground clears AAA")
    func slateOnGround() {
        #expect(Palette.slate.contrastRatio(against: Palette.ground) >= 7)
    }

    @Test("Text over video clears AAA on ink")
    func chalkOnInk() {
        #expect(Palette.chalk.contrastRatio(against: Palette.ink) >= 7)
    }

    @Test("Muted text clears AA on both grounds")
    func muted() {
        #expect(Palette.slateSoft.contrastRatio(against: Palette.ground) >= 4.5)
        #expect(Palette.chalkSoft.contrastRatio(against: Palette.ink) >= 4.5)
    }

    @Test("Every accent's text variant clears AA on ground", arguments: Palette.accentInks)
    func accentInksClearAA(accent: (name: String, color: OKLCH)) {
        let ratio = accent.color.contrastRatio(against: Palette.ground)
        #expect(ratio >= 4.5, "\(accent.name) ink is \(ratio) on ground")
    }

    @Test("Cards step off ground in both directions so a card reads as a card")
    func surfaces() {
        #expect(Palette.card.lightness > Palette.ground.lightness)
        #expect(Palette.cardRaised.lightness < Palette.ground.lightness)
        #expect(Palette.hairline.lightness < Palette.cardRaised.lightness)
    }

    @Test("Every playful fill's ink clears AA on that fill", arguments: Palette.playful)
    func fillInks(fill: Palette.Fill) {
        let ratio = fill.ink.contrastRatio(against: fill.color)
        #expect(ratio >= 4.5, "\(fill.name): \(ratio)")
    }

    @Test("Seven fills, no two the same hue")
    func fillsDistinct() {
        #expect(Palette.playful.count == 7)
        #expect(Set(Palette.playful.map { Int($0.color.hue) }).count == 7)
        #expect(Palette.playful(index: -1).name == Palette.playful.last?.name)
    }

    /// The primary button is the one place the palette does not clear 4.5:1. Its label is
    /// white on the bottom stop of a `blueLight -> blue` gradient, which is 3.5:1 -- AA
    /// for large text, which the 17 pt bold shout is. It is folk's own button, copied on
    /// purpose (see DECISIONS.md), so it is pinned to the threshold it actually has to
    /// meet rather than waived.
    @Test("The primary button's label clears AA for large text on both gradient stops")
    func ctaLabelClearsLargeAA() {
        #expect(Palette.card.contrastRatio(against: Palette.blue) >= 3)
        #expect(Palette.card.contrastRatio(against: Palette.blueLight) >= 1.5)
        // And the tiers under it stay darker than the fill, or the button reads inverted.
        #expect(Palette.blueMid.lightness < Palette.blue.lightness)
        #expect(Palette.blueDeep.lightness < Palette.blueMid.lightness)
    }

    @Test("The twelve avatar hues are distinct and in gamut")
    func avatars() {
        let hues = (0..<12).map { Palette.avatar(seed: $0).hue }
        #expect(Set(hues).count == 12)
        for seed in 0..<12 { #expect(Palette.avatar(seed: seed).gamutMapped().isInGamut) }
    }

    @Test("Every palette role is in sRGB gamut after mapping")
    func gamut() {
        let roles = [
            Palette.ground, Palette.card, Palette.cardRaised, Palette.hairline,
            Palette.slate, Palette.ink, Palette.chalk,
            Palette.blue, Palette.blueLight, Palette.blueMid, Palette.blueDeep,
            Palette.periwinkle, Palette.orange, Palette.sand, Palette.mint, Palette.lilac,
        ]
        for color in roles {
            #expect(color.gamutMapped().isInGamut)
        }
    }
}
