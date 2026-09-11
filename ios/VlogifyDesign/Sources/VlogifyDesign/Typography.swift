import SwiftUI

/// Type roles.
///
/// Three voices, each with a job (chingo's rule, kept):
/// - **Game voice — Bagel Fat One.** The wordmark, the hour numerals, button lids.
///   Numbers and short shouts only; the moment a display face sets body copy the app
///   stops looking playful and starts looking generated.
/// - **App voice — SF Pro Rounded.** Everything a person actually reads.
/// - **Human voice — Gloria Hallelujah.** Notes on the day page, empty states: a person
///   talking, not "No data available."
///
/// Both custom faces are bundled OFL files, registered through `UIAppFonts` and asserted
/// at launch in debug builds -- `Font.custom` falls back to the system face *silently*
/// when a PostScript name misses.
public enum Typeface {
    /// PostScript names, NOT filenames.
    public static let bagel = "BagelFatOne-Regular"
    public static let gloria = "GloriaHallelujah"
}

public enum Typography {
    /// The wordmark.
    public static let wordmark = Font.custom(Typeface.bagel, size: 30, relativeTo: .largeTitle)
    /// The hour on the camera, by default. `StampFont` in the app can swap it.
    public static let hour = Font.custom(Typeface.bagel, size: 44, relativeTo: .largeTitle)
    /// Button lids: CREATE, JOIN, SAVE. Two words at most.
    public static let shout = Font.custom(Typeface.bagel, size: 17, relativeTo: .headline)
    /// A big number: the invite code.
    public static let numeral = Font.custom(Typeface.bagel, size: 40, relativeTo: .largeTitle)

    /// Sheet titles, the day-page title.
    public static let title = Font.system(size: 22, weight: .bold, design: .rounded)
    /// A room name on a card.
    public static let cardTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
    /// Body copy.
    public static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    /// Buttons and pills that carry a sentence rather than a shout.
    public static let label = Font.system(size: 16, weight: .semibold, design: .rounded)
    /// Captions, hints, "you + 2 friends".
    public static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
    /// The permissions typewriter.
    public static let mono = Font.system(size: 15, weight: .regular, design: .monospaced)
    public static let monoBold = Font.system(size: 15, weight: .bold, design: .monospaced)

    /// Notes, empty states, the little asides.
    public static let hand = Font.custom(Typeface.gloria, size: 17, relativeTo: .body)
    public static let handSmall = Font.custom(Typeface.gloria, size: 14, relativeTo: .callout)
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
