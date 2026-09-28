import CoreGraphics
import SwiftUI
import Testing
@testable import VlogifyDesign

/// Doodles are strokes in a unit square, drawn by code. The claims that keep them
/// drawable: every point lands on the page, the same doodle draws the same way every
/// launch, and the home clock's hands point where the time says.
struct DoodleTests {
    private static func inUnitSquare(_ strokes: [[CGPoint]]) -> Bool {
        strokes.allSatisfy { stroke in
            !stroke.isEmpty && stroke.allSatisfy { (-0.02...1.02).contains($0.x) && (-0.02...1.02).contains($0.y) }
        }
    }

    @Test("Every doodle stays inside its unit square", arguments: Doodle.allCases)
    func staysOnThePage(_ doodle: Doodle) {
        #expect(Self.inUnitSquare(doodle.strokes))
    }

    @Test("A doodle draws the same way twice")
    func deterministic() {
        #expect(Doodle.pencil.strokes == Doodle.pencil.strokes)
        #expect(Doodle.clock(hour: 19, minute: 12) == Doodle.clock(hour: 19, minute: 12))
    }

    @Test("The home clock stays on the page at every hour", arguments: [0, 3, 7, 12, 19, 23])
    func clockOnThePage(hour: Int) {
        #expect(Self.inUnitSquare(Doodle.clock(hour: hour, minute: 45)))
    }

    @Test("The home clock shares the onboarding clock's face")
    func sameFace() {
        #expect(Doodle.clock(hour: 7, minute: 0).first == Doodle.clock.strokes.first)
    }

    @Test("At 7:00 the minute hand points up and the hour hand down-left")
    func handsPointAtTheTime() throws {
        let strokes = Doodle.clock(hour: 19, minute: 0)
        let hourTip = try #require(strokes[1].last)
        let minuteTip = try #require(strokes[2].last)
        #expect(minuteTip.y < 0.35 && abs(minuteTip.x - 0.5) < 0.03)
        #expect(hourTip.x < 0.5 && hourTip.y > 0.53)
    }

    @Test("A ruled line spans nearly the whole width and stays near the middle")
    func ruledLine() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 10)
        let bounds = PenLine(seed: 3).path(in: rect).boundingRect
        #expect(bounds.width > 270 && bounds.width <= 300)
        #expect(bounds.minY >= 0 && bounds.maxY <= 10)
    }
}
