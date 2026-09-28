import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Type roles.
///
/// One voice: **the pen hand, for everything.** Titles, body, buttons, captions, the
/// wordmark -- all written, like the drawings they sit next to. Yomogi (OFL) covers
/// Latin, Vietnamese, Cyrillic and Japanese; Gaegu (OFL) is cascaded in for Hangul, which
/// Yomogi lacks; the few Traditional Chinese characters Yomogi's kanji miss fall through to
/// the system face. The hand has one weight, so hierarchy is size and space, never bold.
///
/// Two exceptions, both about reading at a glance: the hour on the camera is SF Pro at its
/// heaviest (it sits on moving video and has to read in a second), and the typewriter mono.
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
    /// The hour on the camera: full bold, because it is read over moving video.
    public static let hour = Font.system(size: 48, weight: .black)
    /// Button labels.
    public static let shout = handFont(size: 22, relativeTo: .headline)
    /// A big number: the invite code. The code alphabet has no I, L or O to confuse.
    public static let numeral = handFont(size: 46, relativeTo: .largeTitle)

    /// Sheet titles, the onboarding questions.
    public static let title = handFont(size: 30, relativeTo: .title)
    /// A room name on a card.
    public static let cardTitle = handFont(size: 22, relativeTo: .headline)
    /// Body copy.
    public static let body = handFont(size: 20, relativeTo: .body)
    /// Buttons and pills that carry a sentence rather than a shout.
    public static let label = handFont(size: 20, relativeTo: .callout)
    /// Captions, hints, "you + 2 friends".
    public static let caption = handFont(size: 16, relativeTo: .caption)
    /// The permissions typewriter.
    public static let mono = Font.system(size: 15, weight: .regular, design: .monospaced)
    public static let monoBold = Font.system(size: 15, weight: .bold, design: .monospaced)

    /// Notes, empty states, the little asides.
    public static let hand = handFont(size: 20, relativeTo: .body)
    public static let handSmall = handFont(size: 17, relativeTo: .footnote)
    /// Coach-mark annotations next to a drawn arrow.
    public static let annotation = handFont(size: 22, relativeTo: .title3)
    /// A big written line: "meet you."
    public static let handTitle = handFont(size: 32, relativeTo: .title)

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
