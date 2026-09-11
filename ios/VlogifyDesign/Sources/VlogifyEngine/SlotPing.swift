import Foundation

/// The minute within an hour when a room gets its ping.
///
/// Every member of a room receives the same nudge at the same moment -- that is what
/// makes the clips line up as "everyone's 5 o'clock". It has to be unpredictable to the
/// members (or it is not a candid), and it has to be computable on a phone that is
/// offline at 3 AM so local notifications can be scheduled a whole day ahead. Both are
/// satisfied by a hash of (room, day, hour) instead of a random number the server
/// hands out: the mock backend, the real backend and the phone all agree with no
/// round-trip.
///
/// FNV-1a rather than `Hasher`: Swift's hasher is seeded per process on purpose, so
/// `hashValue` would give a different minute on every launch.
public enum SlotPing {
    /// The whole hour is capturable; the ping is the nudge, not the gate. Keeping
    /// the minute under 50 leaves at least ten minutes to open the app and shoot.
    public static let latestMinute = 50

    public static func minute(room roomID: String, slot: Slot) -> Int {
        // Fold the high bits down before the modulo: FNV's low bits correlate on
        // strings that differ only in a short suffix, which is exactly what "/4"
        // through "/27" are.
        let hash = mix(fnv1a("\(roomID)|\(slot.key)"))
        return Int(hash % UInt64(latestMinute + 1))
    }

    public static func fireDate(room roomID: String, slot: Slot, in timeZone: TimeZone) -> Date {
        DayClock.date(of: slot.day, hour: slot.hour,
                      minute: minute(room: roomID, slot: slot), in: timeZone)
    }

    /// splitmix64 finaliser. Fixed constants, no state: still reproducible on the server.
    static func mix(_ input: UInt64) -> UInt64 {
        var z = input
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }

    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
