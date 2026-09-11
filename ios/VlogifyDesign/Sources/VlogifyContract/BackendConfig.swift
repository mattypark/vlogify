import Foundation

/// What counts as a configured backend.
///
/// The presence of configuration is the switch, and its absence is a working state
/// rather than a broken one: with no `Secrets.xcconfig` the app runs on `MockBackend`,
/// which is the whole product minus other people's phones. A flag can disagree with
/// reality; a URL cannot.
public struct BackendConfig: Equatable, Sendable {
    public let supabaseURL: URL
    public let anonKey: String
    public let mediaBaseURL: URL

    public init?(supabaseURL rawURL: String?, anonKey rawKey: String?, mediaBaseURL rawMedia: String?) {
        guard let url = BackendConfig.url(from: rawURL),
              let key = BackendConfig.clean(rawKey),
              let media = BackendConfig.url(from: rawMedia)
        else { return nil }
        supabaseURL = url
        anonKey = key
        mediaBaseURL = media
    }

    /// Rejects the empty string, an unsubstituted `$(VAR)` (which is what Info.plist
    /// carries when the xcconfig is absent), and anything that is not https --
    /// localhost excepted in debug builds so the backend session can point at a local
    /// Supabase.
    static func url(from raw: String?) -> URL? {
        guard let clean = clean(raw), let url = URL(string: clean), let host = url.host else { return nil }
        if url.scheme == "https" { return url }
        #if DEBUG
        if url.scheme == "http", host == "localhost" || host == "127.0.0.1" { return url }
        #endif
        return nil
    }

    static func clean(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
