import Foundation
import VlogifyContract
import os

/// Where clips live on the phone.
///
/// A clip the user records is written here *first* and uploaded second, so a dropped
/// connection at 5:03 PM costs nothing -- the tile fills locally, the upload retries
/// on the next foreground. Friends' clips are pulled on view (and today's on every
/// foreground) and cached under the same layout, so the player never streams twice and
/// the clips outlive the backend's seven-day copy. The directory is in the app group
/// container so a future widget can read today's tiles.
final class LocalMediaCache: Sendable {
    let root: URL
    private let logger = Logger(subsystem: "com.matthewpark.vlogify", category: "cache")

    init(root: URL? = nil) {
        let base = root
            ?? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.matthewpark.vlogify")
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.root = base.appendingPathComponent("clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = self.root
        try? url.setResourceValues(values)
    }

    /// The canonical local path for a clip, uploaded or not. Keyed by clip id: a vlog
    /// room takes any number of clips in one hour, and an hour-member path made the
    /// second overwrite the first.
    func url(for clip: Clip) -> URL {
        root.appendingPathComponent("\(clip.roomID)/\(clip.day)/\(clip.id).mov")
    }

    func has(_ clip: Clip) -> Bool {
        FileManager.default.fileExists(atPath: url(for: clip).path)
    }

    /// Moves a freshly recorded file into place.
    func store(recording: URL, as clip: Clip) throws -> URL {
        let destination = url(for: clip)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: recording, to: destination)
        return destination
    }

    /// Ensures a friend's clip is local, fetching it through the media store if not.
    func localURL(for clip: Clip, media: any MediaStore) async throws -> URL {
        let destination = url(for: clip)
        if FileManager.default.fileExists(atPath: destination.path) { return destination }
        let remote = try await media.downloadURL(storageKey: clip.storageKey)
        if remote.isFileURL { return remote }
        let (temp, _) = try await URLSession.shared.download(from: remote)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
        return destination
    }

    /// Bytes on disk, for the settings screen.
    var sizeOnDisk: Int64 {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    func wipe() {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        logger.info("cache wiped")
    }
}
