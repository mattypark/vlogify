import Foundation
import SwiftUI

/// The language the app speaks, chosen in the app, not in Settings.
///
/// First launch asks; the answer is stored and used everywhere after that. Two
/// mechanisms have to agree for that to be true: SwiftUI `Text` reads the environment
/// locale, and `String(localized:)` reads a bundle -- so the root view sets the locale
/// and every `String(localized:)` in the app passes `bundle: .app`. `AppleLanguages` is
/// written too, so the parts iOS draws itself (the Sign in with Apple button, alerts,
/// the keyboard) follow on the next launch.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en, ko, ja, zhHant = "zh-Hant", vi, ru

    var id: String { rawValue }

    /// Shown in its own script, never translated: the one label a person must be
    /// able to read before they have chosen.
    var nativeName: String {
        switch self {
        case .en: return "English"
        case .ko: return "한국어"
        case .ja: return "日本語"
        case .zhHant: return "繁體中文"
        case .vi: return "Tiếng Việt"
        case .ru: return "Русский"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    private static let key = "appLanguage"

    /// Nil until chosen. `-vlogifyLocale xx` forces one for screenshots and the walker.
    static var current: AppLanguage? {
        get {
            if let forced = LaunchArguments.locale, let language = AppLanguage(rawValue: forced) { return language }
            return UserDefaults.standard.string(forKey: key).flatMap(AppLanguage.init(rawValue:))
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: key)
            // So system-drawn UI matches after the next launch. Harmless if unchanged.
            if let newValue { UserDefaults.standard.set([newValue.rawValue], forKey: "AppleLanguages") }
        }
    }

    /// Best guess from the device for the picker's initial highlight.
    static var suggested: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh") { return .zhHant }
        return AppLanguage(rawValue: String(preferred.prefix(2))) ?? .en
    }
}

extension Bundle {
    /// The lproj for the chosen language, so `String(localized:bundle:)` matches what
    /// `Text` shows. Falls back to the main bundle (English) if the lproj is missing.
    static var app: Bundle {
        guard let language = AppLanguage.current,
              let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
