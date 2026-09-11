import AVFoundation
import Observation
import UserNotifications

/// Camera, microphone and notifications: the three things the intro screen walks
/// through, and the three things the camera checks again before it records.
@MainActor
@Observable
final class Permissions {
    enum Status: Equatable { case unasked, granted, denied }

    var camera: Status = .unasked
    var microphone: Status = .unasked
    var notifications: Status = .unasked

    private let forced: String?

    init(forced: String? = LaunchArguments.permissions) {
        self.forced = forced
        if let forced {
            let status: Status = forced == "granted" ? .granted : forced == "denied" ? .denied : .unasked
            camera = status; microphone = status; notifications = status
        }
    }

    func refresh() async {
        guard forced == nil else { return }
        camera = Self.status(AVCaptureDevice.authorizationStatus(for: .video))
        microphone = Self.status(AVCaptureDevice.authorizationStatus(for: .audio))
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notifications = .granted
        case .denied: notifications = .denied
        default: notifications = .unasked
        }
    }

    func requestCamera() async {
        guard forced == nil else { return }
        camera = await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
    }

    func requestMicrophone() async {
        guard forced == nil else { return }
        microphone = await AVCaptureDevice.requestAccess(for: .audio) ? .granted : .denied
    }

    func requestNotifications() async {
        guard forced == nil else { return }
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        notifications = granted ? .granted : .denied
    }

    var canRecord: Bool { camera == .granted && microphone == .granted }
    /// Explicitly refused, as opposed to not asked yet. Only this shows the wall.
    var isDenied: Bool { camera == .denied || microphone == .denied }

    private static func status(_ raw: AVAuthorizationStatus) -> Status {
        switch raw {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        default: return .unasked
        }
    }
}
