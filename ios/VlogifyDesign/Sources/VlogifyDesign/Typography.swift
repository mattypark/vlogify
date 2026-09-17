import SwiftUI

/// Type roles.
///
/// One bundled face, doing one job:
/// - **The wordmark — Bagel Fat One.** Nothing else. It is a logotype now, not a voice.
/// - **Everything else — SF Pro.** Heavy for shouts and numerals, regular for reading.
///   folk's display face is a tight gothic, and SF Pro Display Heavy is the closest thing
///   already on the device; SF Pro Text is what the reading copy wants next to it.
///
/// Rounded is gone with the warm palette, and so is Gloria: handwriting on a cool
/// blue-white ground reads as two apps arguing. A note now looks like a note because of
/// where it sits, not because of the letterforms.
///
/// The one bundled face is an OFL file, registered through `UIAppFonts` and asserted at
/// launch in debug builds -- `Font.custom` falls back to the system face *silently* when a
/// PostScript name misses.
public enum Typeface {
    /// PostScript name, NOT a filename.
    public static let bagel = "BagelFatOne-Regular"
}

public enum Typography {
    /// The wordmark.
    public static let wordmark = Font.custom(Typeface.bagel, size: 30, relativeTo: .largeTitle)
    /// The hour on the camera, by default. `StampFont` in the app can swap it.
    public static let hour = Font.system(size: 44, weight: .heavy)
    /// Button lids: CREATE, JOIN, SAVE. Two words at most.
    public static let shout = Font.system(size: 17, weight: .heavy)
    /// A big number: the invite code.
    public static let numeral = Font.system(size: 40, weight: .heavy)

    /// Sheet titles, the day-page title.
    public static let title = Font.system(size: 22, weight: .bold)
    /// A room name on a card.
    public static let cardTitle = Font.system(size: 17, weight: .semibold)
    /// Body copy.
    public static let body = Font.system(size: 16, weight: .regular)
    /// Buttons and pills that carry a sentence rather than a shout.
    public static let label = Font.system(size: 16, weight: .semibold)
    /// Captions, hints, "you + 2 friends".
    public static let caption = Font.system(size: 13, weight: .medium)
    /// The permissions typewriter.
    public static let mono = Font.system(size: 15, weight: .regular, design: .monospaced)
    public static let monoBold = Font.system(size: 15, weight: .bold, design: .monospaced)

    /// Notes, empty states, the little asides.
    public static let hand = Font.system(size: 17, weight: .regular)
    public static let handSmall = Font.system(size: 14, weight: .regular)
}

public extension Font {
    static let vlogWordmark = Typography.wordmark
    static let vlogHour = Typography.hour
    static let vlogShout = Typography.shout
    static let vlogNumeral = Typography.numeral
    static let vlogTitle = Typography.title
    static let vlogCardTitle = Typography.cardTitle
    static let vlogBody = Typography.body
    static let vlogLabel = Typography.label
    static let vlogCaption = Typography.caption
    static let vlogMono = Typography.mono
    static let vlogMonoBold = Typography.monoBold
    static let vlogHand = Typography.hand
    static let vlogHandSmall = Typography.handSmall
}
