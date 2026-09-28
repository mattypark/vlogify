import Foundation
import VlogifyContract
import VlogifyEngine
import os

/// Clips that are on this phone but not yet confirmed by the backend.
///
/// The camera writes the file into `LocalMediaCache` first, adds the clip here, then
/// tries to send it. If the network drops at 5:03 PM the clip stays in this list (on
/// disk, next to the clips) and goes out on the next foreground. Screens merge pending
/// clips into what the backend returns, so a clip never disappears from its own room
/// while it waits.
///
/// Sending is idempotent on the clip id: a retry after the post landed but the response
/// was lost gets the same clip back from the backend, not "already posted".
@MainActor
final class UploadQueue {
    private(set) var pending: [Clip] = []
    private let file: URL
    private var flushing = false
    private let logger = Logger(subsystem: "com.matthewpark.vlogify", category: "uploads")

    init(cache: LocalMediaCache) {
        file = cache.root.deletingLastPathComponent().appendingPathComponent("pending-uploads.json")
        if let data = try? Data(contentsOf: file),
           let saved = try? JSONDecoder.contract.decode([Clip].self, from: data) {
            pending = saved
        }
    }

    func add(_ clip: Clip) {
        pending.removeAll { $0.id == clip.id }
        pending.append(clip)
        persist()
    }

    func remove(_ id: ClipID) {
        pending.removeAll { $0.id == id }
        persist()
    }

    func pending(in roomID: RoomID, day: DayKey) -> [Clip] {
        pending.filter { $0.roomID == roomID && $0.day == day }
    }

    /// Uploads the bytes and posts the metadata. Throws what the backend said so the
    /// camera can tell the person; the caller decides whether the clip stays queued.
    func send(_ clip: Clip, backend: Backend, cache: LocalMediaCache) async throws -> Clip {
        var outgoing = clip
        let signed = try await backend.media.uploadURL(for: outgoing)
        outgoing.storageKey = signed.storageKey
        try await backend.media.upload(fileURL: cache.url(for: clip), to: signed)
        let posted = try await backend.clips.post(outgoing)
        remove(clip.id)
        return posted
    }

    /// Retries everything waiting. A clip the backend refuses for good (a rule, not the
    /// network) is dropped from the queue -- the file stays on the phone, which is where
    /// the person's clips live anyway.
    func flush(backend: Backend, cache: LocalMediaCache) async -> Int {
        guard !flushing, !pending.isEmpty else { return 0 }
        flushing = true
        defer { flushing = false }
        var sent = 0
        for clip in pending {
            guard cache.has(clip) else {
                remove(clip.id)
                continue
            }
            do {
                _ = try await send(clip, backend: backend, cache: cache)
                sent += 1
            } catch let error as ContractError where Self.isPermanent(error) {
                logger.info("dropping queued clip \(clip.id, privacy: .public): \(String(describing: error), privacy: .public)")
                remove(clip.id)
            } catch {
                // Offline or the server hiccuped. Leave it for the next foreground.
                logger.info("clip \(clip.id, privacy: .public) still queued")
            }
        }
        return sent
    }

    static func isPermanent(_ error: ContractError) -> Bool {
        switch error {
        case .slotAlreadyPosted, .clipTooLong, .notMember, .roomNotFound, .notOwner: true
        default: false
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder.contract.encode(pending)
            try data.write(to: file, options: .atomic)
        } catch {
            logger.error("couldn't persist the upload queue: \(error.localizedDescription, privacy: .public)")
        }
    }
}
