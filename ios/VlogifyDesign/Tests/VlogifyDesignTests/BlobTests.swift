import SwiftUI
import Testing
@testable import VlogifyDesign

struct BlobTests {
    @Test("Every seed gives a closed path that stays inside its rect", arguments: 0..<200)
    func inBounds(seed: Int) {
        let rect = CGRect(x: 10, y: 20, width: 120, height: 80)
        let path = BlobShape(seed: UInt64(seed)).path(in: rect)
        let bounds = path.boundingRect
        #expect(!path.isEmpty)
        #expect(rect.insetBy(dx: -2, dy: -2).contains(bounds), "seed \(seed) escaped: \(bounds)")
    }

    @Test("The same seed draws the same blob; different seeds differ")
    func deterministic() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let a = BlobShape(seedString: "mascot").path(in: rect)
        let b = BlobShape(seedString: "mascot").path(in: rect)
        let c = BlobShape(seedString: "moon").path(in: rect)
        #expect(a.description == b.description)
        #expect(a.description != c.description)
    }

    @Test("Anchors are never collinear circles: wobble moves them")
    func wobbles() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let radii = BlobShape.anchors(seed: 7, points: 7, wobble: 0.4, in: rect)
            .map { hypot($0.x - 50, $0.y - 50) }
        #expect(Set(radii.map { Int($0) }).count > 2)
    }
}
