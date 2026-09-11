import Testing
@testable import VlogifyEngine

struct StitchPlanTests {
    @Test("Every member count from 1 to 20 tiles the canvas without gaps or overlap", arguments: 1...20)
    func tiles(count: Int) {
        let plan = StitchPlan(memberCount: count)
        #expect(plan.tiles.count == count)
        let (columns, rows) = StitchPlan.grid(for: count)
        #expect(columns * rows >= count)
        for tile in plan.tiles {
            #expect(tile.x >= 0 && tile.x + tile.width <= 1.0001)
            #expect(tile.y >= 0 && tile.y + tile.height <= 1.0001)
            // Portrait or square, never landscape: these are phone clips.
            #expect(tile.width * Double(StitchPlan.exportWidth) <= tile.height * Double(StitchPlan.exportHeight) + 0.5)
        }
        let area = plan.tiles.reduce(0) { $0 + $1.width * $1.height }
        #expect(area <= 1.0001)
    }

    @Test("Two people are side by side, four are a grid")
    func shapes() {
        #expect(StitchPlan.grid(for: 2) == (2, 1))
        #expect(StitchPlan.grid(for: 4) == (2, 2))
        #expect(StitchPlan.grid(for: 20) == (4, 5))
    }

    @Test("Segments are consecutive and skip empty hours")
    func segments() {
        let day = DayKey(year: 2026, month: 9, day: 11)
        let posted = [Slot(day: day, hour: 9), Slot(day: day, hour: 4), Slot(day: day, hour: 17)]
        let segments = StitchPlan.segments(for: posted, clipDuration: 2)
        #expect(segments.map(\.slot.hour) == [4, 9, 17])
        #expect(segments.map(\.start) == [0, 2, 4])
        #expect(StitchPlan.totalDuration(slotCount: 3, clipDuration: 2) == 6)
    }
}
