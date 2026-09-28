import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Type roles.
///
/// Two voices, and the second one is the secondary one:
/// - **SF Pro -- everything you read and press.** Titles, body, buttons, the invite
///   code. The app's own voice is plain.
/// - **A pen hand -- everything written *on* the page.** Notes, annotations and the
///   arrows' labels, the hour stamp, the wordmark, the hours down a room. Yomogi (OFL)
///   covers Latin, Vietnamese, Cyrillic and Japanese; Gaegu (OFL) is cascaded in for
///   Hangul, which Yomogi lacks. Traditional Chinese falls through to the system face
///   for the few characters Yomogi's kanji do not cover.
///
/// Bundled faces register through `UIAppFonts` and are asserted at launch in debug
/// builds -- `Font.custom` falls back to the system face *silently* when a PostScript
/// name misses.
public enum Typeface {
    /// PostScript names, NOT filenames.
    public static let hand = "Yomogi-Regular"
    public static let handKorean = "Gaegu-Regular"
    /// Retired as the wordmark; still offered as one of the camera stamp faces.
    public static let bagel = "BagelFatOne-Regular"

    public static let bundled = [hand, handKorean, bagel]
}

public enum Typography {
    /// The wordmark: "vlogify", written.
    public static let wordmark = handFont(size: 36, relativeTo: .largeTitle)
    /// The hour on the camera, by default. `StampFont` in the app can swap it.
    public static let hour = handFont(size: 46, relativeTo: .largeTitle)
    /// Button labels. Plain and firm; the outline around them is what is drawn.
    public static let shout = Font.system(size: 17, weight: .semibold)
    /// A big number: the invite code.
    public static let numeral = Font.system(size: 38, weight: .bold, design: .monospaced)

    /// Sheet titles, the onboarding lines.
    public static let title = Font.system(size: 24, weight: .bold)
    /// A room name on a card.
    public static let cardTitle = Font.system(size: 17, weight: .semibold)
    /// Body copy.
    public static let body = Font.system(size: 16, weight: .regular)
    /// Buttons and pills that carry a sentence rather than a shout.
    public static let label = Font.system(size: 16, weight: .medium)
    /// Captions, hints, "you + 2 friends".
    public static let caption = Font.system(size: 13, weight: .medium)
    /// The permissions typewriter.
    public static let mono = Font.system(size: 15, weight: .regular, design: .monospaced)
    public static let monoBold = Font.system(size: 15, weight: .bold, design: .monospaced)

    /// Notes, empty states, the little asides.
    public static let hand = handFont(size: 19, relativeTo: .body)
    public static let handSmall = handFont(size: 16, relativeTo: .footnote)
    /// Coach-mark annotations next to a drawn arrow.
    public static let annotation = handFont(size: 21, relativeTo: .title3)
    /// A big written line: "meet you."
    public static let handTitle = handFont(size: 30, relativeTo: .title)

    /// The hand face at a size, with Hangul cascaded to Gaegu and scaled with Dynamic
    /// Type from the given style.
    public static func handFont(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        #if canImport(UIKit)
        guard let base = handUIFont(size: size) else { return .system(size: size) }
        return Font(UIFontMetrics(forTextStyle: style.uiKit).scaledFont(for: base))
        #else
        return .custom(Typeface.hand, size: size, relativeTo: style)
        #endif
    }

    #if canImport(UIKit)
    /// The same face for UIKit and Core Text callers (navigation bars, the compositor).
    public static func handUIFont(size: CGFloat) -> UIFont? {
        guard UIFont(name: Typeface.hand, size: size) != nil else { return nil }
        let korean = UIFontDescriptor(name: Typeface.handKorean, size: size)
        let descriptor = UIFontDescriptor(name: Typeface.hand, size: size)
            .addingAttributes([.cascadeList: [korean]])
        return UIFont(descriptor: descriptor, size: size)
    }
    #endif
}

#if canImport(UIKit)
private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}
#endif

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
    static let vlogAnnotation = Typography.annotation
    static let vlogHandTitle = Typography.handTitle
}
