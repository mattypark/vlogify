import Foundation
import VlogifyEngine

/// Presence by polling. Every `pollInterval` the room's day log for today (the app-day, by
/// `DayClock` in the phone's time zone) is fetched, and whatever changed since the last look
/// is yielded: new clips, people who arrived, people who left. The first look only sets the
/// baseline -- a subscriber already loaded the room. A failed poll is skipped, not fatal.
/// Polling stops when the stream is dropped.
extension CloudflareBackend: PresenceService {
    public func subscribe(roomID: RoomID) -> AsyncStream<RoomEvent> {
        AsyncStream { continuation in
            let task = Task { [self] in
                var known: Snapshot?
                while !Task.isCancelled {
                    let today = DayClock.dayKey(for: now(), in: timeZone)
                    if let log = try? await day(roomID: roomID, day: today) {
                        let next = Snapshot(log)
                        if let known {
                            for event in known.events(to: next) { continuation.yield(event) }
                        }
                        known = next
                    }
                    do {
                        try await Task.sleep(for: pollInterval)
                    } catch {
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// One look at a room, reduced to what presence reports on.
struct Snapshot: Sendable {
    let clipIDs: Set<ClipID>
    let members: [UserID: Membership]
    let clips: [Clip]

    init(_ log: DayLog) {
        clipIDs = Set(log.clips.map(\.id))
        members = Dictionary(log.members.map { ($0.userID, $0) }, uniquingKeysWith: { first, _ in first })
        clips = log.clips
    }

    /// What happened between `self` and `next`, members first so a newcomer's first clip
    /// arrives after they do. Stable order: joins by join date, clips as the log lists them.
    func events(to next: Snapshot) -> [RoomEvent] {
        let joined = next.members.values
            .filter { members[$0.userID] == nil }
            .sorted { ($0.joinedAt, $0.userID) < ($1.joinedAt, $1.userID) }
            .map(RoomEvent.memberJoined)
        let left = members.keys
            .filter { next.members[$0] == nil }
            .sorted()
            .map(RoomEvent.memberLeft)
        let posted = next.clips
            .filter { !clipIDs.contains($0.id) }
            .map(RoomEvent.clipPosted)
        return joined + left + posted
    }
}
