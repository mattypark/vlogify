import Foundation

/// What counts as a configured backend.
///
/// The presence of configuration is the switch, and its absence is a working state
/// rather than a broken one: with no API URL the app runs on `MockBackend`, which is
/// the whole product minus other people's phones. A flag can disagree with reality; a
/// URL cannot.
///
/// One value: the Cloudflare Worker's base URL. It is not a secret -- every request is
/// authenticated by the session token, not by knowing where the Worker lives -- so it
/// is committed in `Base.xcconfig` rather than hidden in `Secrets.xcconfig`.
public struct BackendConfig: Equatable, Sendable {
    public let apiBaseURL: URL

    public init?(apiBaseURL rawURL: String?) {
        guard let url = BackendConfig.url(from: rawURL) else { return nil }
        apiBaseURL = url
    }

    /// Rejects the empty string, an unsubstituted `$(VAR)` (which is what Info.plist
    /// carries when the xcconfig leaves it blank), and anything that is not https --
    /// localhost excepted in debug builds so a `wrangler dev` Worker can be used.
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
