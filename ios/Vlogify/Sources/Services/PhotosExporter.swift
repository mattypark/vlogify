import Photos

/// Saves a finished day to the camera roll. Add-only access: the app never reads the
/// library, and the permission prompt says so.
enum PhotosExporter {
    enum Failure: Error { case denied, failed }

    static func save(video url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw Failure.denied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        } catch {
            throw Failure.failed
        }
    }
}
