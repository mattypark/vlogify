import Foundation
import Testing
@testable import VlogifyContract

struct MarkTests {
    @Test("A mark round-trips through its wire string exactly")
    func roundTrip() throws {
        for index in 0..<4 {
            let mark = Mark.sample(index)
            let decoded = try #require(Mark(encoded: mark.encoded))
            #expect(decoded == mark)
            #expect(!mark.encoded.contains("="))
            #expect(!mark.encoded.contains("+"))
            #expect(!mark.encoded.contains("/"))
        }
    }

    @Test("Points are clamped to the unit square and snapped to the 256-step grid")
    func clampAndQuantise() {
        let mark = Mark(strokes: [[MarkPoint(x: -3, y: 0.5), MarkPoint(x: 9, y: .nan), MarkPoint(x: 0.5, y: 0.5)]])
        let points = mark.strokes.flatMap { $0 }
        #expect(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        #expect(points.allSatisfy { ($0.x * 255).rounded() == $0.x * 255 })
    }

    @Test("Consecutive duplicate points collapse, empty strokes vanish")
    func dedupe() {
        let p = MarkPoint(x: 0.5, y: 0.5)
        let mark = Mark(strokes: [[p, p, p], []])
        #expect(mark.strokes.count == 1)
        #expect(mark.strokes[0].count == 1)
        #expect(Mark(strokes: [[], []]).isEmpty)
    }

    @Test("A scribble far over the caps is simplified until it fits the wire budget")
    func caps() throws {
        // 70 strokes of 200 jittery points each: 14,000 points before simplifying.
        var generator = SeededGenerator(seed: 42)
        let strokes = (0..<70).map { stroke in
            (0..<200).map { step -> MarkPoint in
                let jitter = Double(generator.next() % 1000) / 1000 * 0.01
                return MarkPoint(x: Double(step) / 200, y: Double(stroke) / 70 + jitter)
            }
        }
        let mark = Mark(strokes: strokes)
        #expect(mark.strokes.count <= Mark.maxStrokes)
        #expect(mark.pointCount <= Mark.maxPoints)
        #expect(mark.encoded.count <= Mark.maxEncodedLength)
        #expect(try #require(Mark(encoded: mark.encoded)) == mark)
    }

    @Test("A single stroke longer than a byte can count is split, not truncated")
    func longStroke() throws {
        // A circle: nothing for simplification to drop at this tolerance.
        let circle = (0..<600).map { step -> MarkPoint in
            let angle = Double(step) / 600 * 2 * .pi
            return MarkPoint(x: 0.5 + cos(angle) * 0.45, y: 0.5 + sin(angle) * 0.45)
        }
        let mark = Mark(strokes: [circle])
        #expect(mark.strokes.allSatisfy { $0.count <= 255 })
        #expect(try #require(Mark(encoded: mark.encoded)) == mark)
    }

    @Test("Malformed wire strings are refused")
    func malformed() {
        #expect(Mark(encoded: "") == nil)
        #expect(Mark(encoded: "!!!!") == nil)
        // Version 2.
        #expect(Mark(encoded: Data([2, 1, 10, 10]).base64EncodedString()) == nil)
        // A stroke claiming more points than the bytes hold.
        #expect(Mark(encoded: Data([1, 5, 10, 10]).base64EncodedString()) == nil)
        // A zero-length stroke.
        #expect(Mark(encoded: Data([1, 0]).base64EncodedString()) == nil)
        // Version byte only: no strokes.
        #expect(Mark(encoded: Data([1]).base64EncodedString()) == nil)
        #expect(Mark(encoded: String(repeating: "A", count: Mark.maxEncodedLength + 1)) == nil)
    }

    @Test("Bounds hug the ink, and a lone dot still has a size")
    func bounds() {
        let box = Mark(strokes: [[MarkPoint(x: 0.2, y: 0.3), MarkPoint(x: 0.6, y: 0.9)]]).bounds
        #expect(abs(box.minX - 0.2) < 0.01 && abs(box.maxY - 0.9) < 0.01)
        let dot = Mark(strokes: [[MarkPoint(x: 0.5, y: 0.5)]]).bounds
        #expect(dot.maxX > dot.minX && dot.maxY > dot.minY)
    }

    @Test("The mock stores a drawn mark and shows it to room-mates")
    func mockStoresMark() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mark-\(UUID().uuidString)")
        let mock = MockBackend(clipsDirectory: dir)
        await mock.seed(.full)
        let drawn = Mark.sample(3)
        let me = try await mock.update(mark: drawn)
        #expect(me.mark == drawn)
        let rooms = try await mock.rooms()
        let group = try #require(rooms.first { !$0.isSolo })
        let members = try await mock.members(roomID: group.id)
        #expect(members.first { $0.userID == me.id }?.profile.mark == drawn)
        await #expect(throws: ContractError.unsupported) { try await mock.update(mark: Mark(strokes: [])) }
    }
}
