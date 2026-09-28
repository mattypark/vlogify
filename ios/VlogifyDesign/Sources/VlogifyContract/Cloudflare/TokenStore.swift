import Foundation

/// What a sign-in leaves behind: the bearer token the Worker checks and the session it
/// describes. Persisted as one value so the two can never disagree.
public struct StoredSession: Codable, Sendable, Equatable {
    public let token: String
    public let session: Session

    public init(token: String, session: Session) {
        self.token = token
        self.session = session
    }
}

/// Where `CloudflareBackend` keeps its session between launches. The app's is the
/// Keychain; tests and previews use `InMemoryTokenStore`. Synchronous on purpose: every
/// request reads it, and a Keychain read is microseconds.
public protocol TokenStore: Sendable {
    func load() -> StoredSession?
    func save(_ stored: StoredSession)
    func clear()
}

/// A token store that forgets on quit.
public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: StoredSession?

    public init(_ stored: StoredSession? = nil) {
        self.stored = stored
    }

    public func load() -> StoredSession? {
        lock.withLock { stored }
    }

    public func save(_ stored: StoredSession) {
        lock.withLock { self.stored = stored }
    }

    public func clear() {
        lock.withLock { stored = nil }
    }
}
