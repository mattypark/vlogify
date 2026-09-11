import SwiftUI

/// Type roles.
///
/// Two families where Setlog has three. The rounded system face carries the wordmark,
/// the hour numerals and the sheet titles -- it has the chunk of a display face
/// without costing a byte of bundle or a font licence. The plain system face does the
/// reading. Monospace appears on exactly one screen, the permissions typewriter, where
/// the terminal voice is the joke.
///
/// If the artist hands over a lettered wordmark it lands as an image in `Doodles`,
/// not as a font.
public enum Typography {
    /// The wordmark. Heavy and tight; lowercase at the call site.
    public static let wordmark = Font.system(size: 30, weight: .black, design: .rounded)
    /// The hour on a tile and on the camera. Big enough to read across a room.
    public static let hour = Font.system(size: 44, weight: .heavy, design: .rounded)
    /// Sheet titles, the "your day, side by side." line.
    public static let title = Font.system(size: 22, weight: .bold, design: .rounded)
    /// A room name on a card.
    public static let cardTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
    /// Body copy. Not rounded: at reading sizes rounded terminals cost legibility.
    public static let body = Font.system(size: 16, weight: .regular)
    /// Buttons and pills.
    public static let label = Font.system(size: 16, weight: .semibold)
    /// Captions, hints, "you + 2 friends".
    public static let caption = Font.system(size: 13, weight: .medium)
    /// The permissions typewriter.
    public static let mono = Font.system(size: 15, weight: .regular, design: .monospaced)
    public static let monoBold = Font.system(size: 15, weight: .bold, design: .monospaced)
}

public extension Font {
    static let vlogWordmark = Typography.wordmark
    static let vlogHour = Typography.hour
    static let vlogTitle = Typography.title
    static let vlogCardTitle = Typography.cardTitle
    static let vlogBody = Typography.body
    static let vlogLabel = Typography.label
    static let vlogCaption = Typography.caption
    static let vlogMono = Typography.mono
    static let vlogMonoBold = Typography.monoBold
}
