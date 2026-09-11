import Testing
@testable import VlogifyEngine

struct InviteCodeTests {
    struct Fixed: RandomNumberGenerator {
        var state: UInt64 = 1
        mutating func next() -> UInt64 { state = state &* 6_364_136_223_846_793_005 &+ 1; return state }
    }

    @Test("A generated code round-trips through parsing")
    func roundTrip() {
        var generator = Fixed()
        let code = InviteCode.generate(using: &generator)
        #expect(code.value.count == 6)
        #expect(InviteCode(code.value) == code)
        #expect(InviteCode(code.formatted) == code)
        #expect(InviteCode(code.value.lowercased()) == code)
    }

    @Test("A single-character typo is rejected")
    func typo() {
        var generator = Fixed()
        let code = InviteCode.generate(using: &generator)
        var characters = Array(code.value)
        characters[2] = characters[2] == "7" ? "8" : "7"
        #expect(InviteCode(String(characters)) == nil)
    }

    @Test("Confusable letters map back: I and L to 1, O to 0")
    func confusables() {
        #expect(InviteCode.normalize("o1i-lab") == "0111AB")
        #expect(InviteCode.normalize("ab cd ef") == "ABCDEF")
    }

    @Test("Too short, too long, and junk are all nil")
    func shapes() {
        #expect(InviteCode("ABC") == nil)
        #expect(InviteCode("ABCDEFG") == nil)
        #expect(InviteCode("!!!!!!") == nil)
    }

    @Test("Codes never contain the dropped letters")
    func alphabet() {
        var generator = Fixed()
        for _ in 0..<200 {
            let code = InviteCode.generate(using: &generator).value
            #expect(!code.contains("I") && !code.contains("L") && !code.contains("O") && !code.contains("U"))
        }
    }
}
