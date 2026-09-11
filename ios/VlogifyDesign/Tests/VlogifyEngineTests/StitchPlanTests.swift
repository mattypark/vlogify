import Testing
@testable import VlogifyEngine

struct StitchPlanTests {
    @Test("Every member count from 1 to 20 tiles the canvas without gaps or overlap, both ways",
          arguments: 1...20, [StitchPlan.Orientation.landscape, .portrait])
    func tiles(count: Int, orientation: StitchPlan.Orientation) {
        let plan = StitchPlan(memberCount: count, orientation: orientation)
        #expect(plan.tiles.count == count)
        let (columns, rows) = StitchPlan.grid(for: count, orientation: orientation)
        #expect(columns * rows >= count)
        for tile in plan.tiles {
            #expect(tile.x >= 0 && tile.x + tile.width <= 1.0001)
            #expect(tile.y >= 0 && tile.y + tile.height <= 1.0001)
        }
        let area = plan.tiles.reduce(0) { $0 + $1.width * $1.height }
        #expect(area <= 1.0001)
    }

    @Test("Portrait tiles are never landscape", arguments: 1...20)
    func portraitTiles(count: Int) {
        for tile in StitchPlan(memberCount: count, orientation: .portrait).tiles {
            #expect(tile.width * Double(StitchPlan.exportWidth) <= tile.height * Double(StitchPlan.exportHeight) + 0.5)
        }
    }

    @Test("Landscape tiles are rows, wider than tall, for two to four people", arguments: 2...4)
    func landscapeRows(count: Int) {
        let plan = StitchPlan(memberCount: count, orientation: .landscape)
        #expect(StitchPlan.grid(for: count, orientation: .landscape).columns == 1)
        for tile in plan.tiles {
            #expect(tile.width * Double(StitchPlan.exportWidth) >= tile.height * Double(StitchPlan.exportHeight) - 0.5)
        }
    }

    @Test("Defaults: landscape; two people stack, three portrait people stand side by side")
    func shapes() {
        #expect(StitchPlan(memberCount: 2).orientation == .landscape)
        #expect(StitchPlan.grid(for: 2) == (1, 2))
        #expect(StitchPlan.grid(for: 3, orientation: .portrait) == (3, 1))
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
