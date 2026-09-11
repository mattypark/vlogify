import Foundation
import UserNotifications
import VlogifyContract
import VlogifyEngine
import os

/// Local notifications for the hourly ping.
///
/// The minute is `SlotPing`'s, so it matches what every other member's phone computes
/// and what the server will send when push exists. Planned from the current slot to
/// the end of the app-day on every foreground; iOS caps pending notifications at 64
/// and a day is at most 24 per room, so two pinged rooms fit and a third is trimmed
/// to the nearest hours. Push (backend session) replaces this for rooms the server
/// knows about; local stays as the offline fallback.
@MainActor
final class HourlyScheduler {
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.matthewpark.vlogify", category: "scheduler")
    private static let budget = 60

    func replan(rooms: [Room], clock: Clock) {
        let pinged = rooms.filter { RoomRules.pings($0.type) }
        Task {
            await center.removeAllPendingNotificationRequests()
            let remaining = DayClock.remainingSlots(from: clock.now, in: clock.timeZone)
            var planned = 0
            outer: for slot in remaining {
                for room in pinged {
                    guard planned < Self.budget else { break outer }
                    let fire = SlotPing.fireDate(room: room.id, slot: slot, in: clock.timeZone)
                    guard fire > clock.now else { continue }
                    await schedule(room: room, slot: slot, at: fire, timeZone: clock.timeZone)
                    planned += 1
                }
            }
            logger.info("planned \(planned) pings for \(pinged.count) rooms")
        }
    }

    private func schedule(room: Room, slot: Slot, at date: Date, timeZone: TimeZone) async {
        let content = UNMutableNotificationContent()
        content.title = room.name ?? String(localized: "your room")
        content.body = String(localized: "it's \(slot.label). add your 2s clip.")
        content.sound = .default
        content.userInfo = ["roomID": room.id, "slot": slot.key]
        content.threadIdentifier = room.id

        var components = DayClock.calendar(in: timeZone)
            .dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.timeZone = timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "\(room.id)/\(slot.key)", content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            logger.error("could not schedule \(room.id)/\(slot.key): \(error.localizedDescription)")
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
