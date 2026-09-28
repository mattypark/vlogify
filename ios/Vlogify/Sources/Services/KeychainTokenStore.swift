import Foundation
import VlogifyContract

/// The Worker session, in the Keychain: token and session together, as one JSON item, so a
/// relaunch comes back signed in and a deleted app leaves nothing readable in a backup.
/// Stateless -- every read goes to the Keychain -- which is what makes it `Sendable`.
struct KeychainTokenStore: TokenStore {
    private static let key = "cloudflare-session"

    func load() -> StoredSession? {
        guard let data = Keychain.get(Self.key) else { return nil }
        return try? JSONDecoder.contract.decode(StoredSession.self, from: data)
    }

    func save(_ stored: StoredSession) {
        guard let data = try? JSONEncoder.contract.encode(stored) else { return }
        Keychain.set(data, for: Self.key)
    }

    func clear() {
        Keychain.remove(Self.key)
    }
}
