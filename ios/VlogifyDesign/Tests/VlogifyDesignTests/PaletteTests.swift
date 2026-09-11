import Testing
@testable import VlogifyDesign

/// The design system claims one paper ground carries the whole app and that every
/// word on it is readable. Those are testable claims, so they are tested -- a palette
/// tweak that drops an accent below AA fails here rather than shipping.
struct PaletteTests {
    @Test("Body text on paper clears AAA")
    func sootOnPaper() {
        #expect(Palette.soot.contrastRatio(against: Palette.paper) >= 7)
    }

    @Test("Text over video clears AAA on ink")
    func chalkOnInk() {
        #expect(Palette.chalk.contrastRatio(against: Palette.ink) >= 7)
    }

    @Test("Muted text clears AA on both grounds")
    func muted() {
        #expect(Palette.sootSoft.contrastRatio(against: Palette.paper) >= 4.5)
        #expect(Palette.chalkSoft.contrastRatio(against: Palette.ink) >= 4.5)
    }

    @Test("Every accent's text variant clears AA on paper", arguments: Palette.accentInks)
    func accentInksClearAA(accent: (name: String, color: OKLCH)) {
        let ratio = accent.color.contrastRatio(against: Palette.paper)
        #expect(ratio >= 4.5, "\(accent.name) ink is \(ratio) on paper")
    }

    @Test("Cards step off paper in both directions so a card reads as a card")
    func surfaces() {
        #expect(Palette.card.lightness > Palette.paper.lightness)
        #expect(Palette.cardRaised.lightness < Palette.paper.lightness)
        #expect(Palette.hairline.lightness < Palette.cardRaised.lightness)
    }

    @Test("The twelve avatar hues are distinct and in gamut")
    func avatars() {
        let hues = (0..<12).map { Palette.avatar(seed: $0).hue }
        #expect(Set(hues).count == 12)
        for seed in 0..<12 { #expect(Palette.avatar(seed: seed).gamutMapped().isInGamut) }
    }

    @Test("Every palette role is in sRGB gamut after mapping")
    func gamut() {
        for color in [Palette.paper, Palette.ink, Palette.orchid, Palette.spearmint, Palette.sky, Palette.butter, Palette.ember] {
            #expect(color.gamutMapped().isInGamut)
        }
    }
}
