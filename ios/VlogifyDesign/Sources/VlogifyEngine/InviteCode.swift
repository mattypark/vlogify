import Foundation

/// A six-character room code: five from Crockford's base32 plus one check character.
///
/// Crockford's alphabet drops I, L, O and U so a code read aloud or typed from a photo
/// cannot be mis-keyed on the letters people confuse; `normalize` maps those back in
/// case someone types them anyway. The check character means a typo is caught on the
/// phone before the server is asked, which matters because "join" is the first thing a
/// new user does and a silent server error there is a lost friend.
public struct InviteCode: Hashable, Sendable, CustomStringConvertible {
    public static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    public static let length = 6

    public let value: String

    public var description: String { value }

    /// Parses user input. Returns `nil` unless the normalised text is a well-formed
    /// code whose check character matches.
    public init?(_ input: String) {
        let normalized = InviteCode.normalize(input)
        guard normalized.count == InviteCode.length,
              let checksum = InviteCode.checkCharacter(for: String(normalized.dropLast())),
              normalized.last == checksum
        else { return nil }
        value = normalized
    }

    /// Mints a fresh code from the given generator. The mock backend seeds this with
    /// a fixed generator so screenshots are reproducible.
    public static func generate<G: RandomNumberGenerator>(using generator: inout G) -> InviteCode {
        var body = ""
        for _ in 0..<(length - 1) {
            body.append(alphabet[Int(generator.next() % UInt64(alphabet.count))])
        }
        let check = checkCharacter(for: body) ?? "0"
        // Constructed, not parsed: the check character is correct by construction.
        return InviteCode(unchecked: body + String(check))
    }

    public static func generate() -> InviteCode {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }

    private init(unchecked value: String) {
        self.value = value
    }

    /// Uppercases, strips separators, and maps the confusable letters back.
    public static func normalize(_ input: String) -> String {
        input.uppercased().compactMap { character -> Character? in
            switch character {
            case "I", "L": return "1"
            case "O": return "0"
            case "-", " ", "_": return nil
            default: return alphabet.contains(character) ? character : nil
            }
        }.reduce(into: "") { $0.append($1) }
    }

    /// Weighted sum of the body's symbol values, modulo the alphabet size.
    static func checkCharacter(for body: String) -> Character? {
        var sum = 0
        for (position, character) in body.enumerated() {
            guard let index = alphabet.firstIndex(of: character) else { return nil }
            sum += index * (position + 1)
        }
        return alphabet[sum % alphabet.count]
    }

    /// `AB3-K7Q`, for display and read-aloud.
    public var formatted: String {
        let characters = Array(value)
        return String(characters[0..<3]) + "-" + String(characters[3..<6])
    }
}

/// A code is its six characters on the wire.
extension InviteCode: Codable {
    public init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        guard let code = InviteCode(string) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad invite code"))
        }
        self = code
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
