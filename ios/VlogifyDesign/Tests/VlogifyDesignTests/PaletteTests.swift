import Testing
@testable import VlogifyDesign

/// The design system claims a black-pen-on-paper page carries the whole app and that
/// every word on it is readable. Those are testable claims, so they are tested -- a
/// palette tweak that drops a role below AA fails here rather than shipping.
struct PaletteTests {
    @Test("Pen on paper clears AAA")
    func penOnPaper() {
        #expect(Palette.pen.contrastRatio(against: Palette.ground) >= 7)
        #expect(Palette.pen.contrastRatio(against: Palette.fog) >= 7)
    }

    @Test("Text over video clears AAA on ink")
    func chalkOnInk() {
        #expect(Palette.chalk.contrastRatio(against: Palette.ink) >= 7)
    }

    @Test("Muted text clears AA on both grounds")
    func muted() {
        #expect(Palette.penSoft.contrastRatio(against: Palette.ground) >= 4.5)
        #expect(Palette.chalkSoft.contrastRatio(against: Palette.ink) >= 4.5)
    }

    @Test("Every text-carrying role clears AA on paper", arguments: Palette.accentInks)
    func accentInksClearAA(accent: (name: String, color: OKLCH)) {
        let ratio = accent.color.contrastRatio(against: Palette.ground)
        #expect(ratio >= 4.5, "\(accent.name) is \(ratio) on paper")
    }

    @Test("A picked thing and a divider step down from paper, in that order")
    func surfaces() {
        #expect(Palette.card.lightness >= Palette.ground.lightness)
        #expect(Palette.fog.lightness < Palette.ground.lightness)
        #expect(Palette.hairline.lightness < Palette.fog.lightness)
    }

    @Test("The chrome is achromatic: only red carries chroma")
    func achromatic() {
        for role in [Palette.ground, Palette.card, Palette.fog, Palette.hairline, Palette.pen, Palette.ink, Palette.chalk] {
            #expect(role.chroma < 0.005)
        }
        #expect(Palette.red.chroma > 0.1)
    }

    @Test("Every fill's ink clears AA on that fill", arguments: Palette.fills)
    func fillInks(fill: Palette.Fill) {
        let ratio = fill.ink.contrastRatio(against: fill.color)
        #expect(ratio >= 4.5, "\(fill.name): \(ratio)")
    }

    @Test("Fill picks wrap in both directions")
    func fillIndex() {
        #expect(Palette.fill(index: -1).name == Palette.fills.last?.name)
        #expect(Palette.fill(index: Palette.fills.count).name == Palette.fills.first?.name)
    }

    /// The seed is on the wire (`Profile.avatarSeed`) and older builds still paint with
    /// it, so the twelve hues must never be remapped.
    @Test("The twelve avatar hues are distinct and in gamut")
    func avatars() {
        let hues = (0..<12).map { Palette.avatar(seed: $0).hue }
        #expect(Set(hues).count == 12)
        for seed in 0..<12 { #expect(Palette.avatar(seed: seed).gamutMapped().isInGamut) }
    }

    @Test("Every palette role is in sRGB gamut after mapping")
    func gamut() {
        let roles = [
            Palette.ground, Palette.card, Palette.fog, Palette.hairline,
            Palette.pen, Palette.ink, Palette.chalk, Palette.red,
        ]
        for color in roles {
            #expect(color.gamutMapped().isInGamut)
        }
    }
}
