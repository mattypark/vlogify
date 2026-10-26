import Foundation

/// Design A/B switches. Both sides ship; Release always runs A until a pick makes the
/// winner the only code. In Debug, flip one from the launch arguments:
///
///   -debug.record.variant b     open-ended clips: A tap to start, tap to stop · B hold to film
///   -debug.tour.variant b       first visit: A one thing at a time · B all of it, fading in turn
///
/// `-key value` lands in UserDefaults' argument domain, so no parsing is needed here.
enum DesignVariant: String {
    case a, b

    static var record: DesignVariant { value(for: "debug.record.variant") }
    static var tour: DesignVariant { value(for: "debug.tour.variant") }

    private static func value(for key: String) -> DesignVariant {
        #if DEBUG
        return UserDefaults.standard.string(forKey: key).flatMap(DesignVariant.init(rawValue:)) ?? .a
        #else
        return .a
        #endif
    }
}
