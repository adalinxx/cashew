import Testing
import Foundation
@testable import cashew

@Suite("ContentSource composition adapters")
struct ContentSourceAdaptersTests {
    private func data(_ s: String) -> Data { Data(s.utf8) }

    @Test("Overlay serves local entries first and delegates misses in one batch")
    func overlayHitsThenFallsThrough() async {
        let overlay = OverlayContentSource(
            entries: ["a": data("A")],
            fallback: InMemoryContentSource(["b": data("B"), "a": data("FALLBACK-A")])
        )
        let out = await overlay.fetch(["a", "b", "c"])
        #expect(out["a"] == data("A"), "overlay entry must win over fallback")
        #expect(out["b"] == data("B"), "miss must be served by fallback")
        #expect(out["c"] == nil, "absent CID stays absent")
    }

    @Test("Composite tries sources in precedence order; earlier source wins")
    func compositePrecedence() async {
        let composite = CompositeContentSource([
            InMemoryContentSource(["a": data("A1"), "b": data("B1")]),
            InMemoryContentSource(["b": data("B2"), "c": data("C2")]),
        ])
        let out = await composite.fetch(["a", "b", "c", "d"])
        #expect(out["a"] == data("A1"))
        #expect(out["b"] == data("B1"), "first source with the CID wins")
        #expect(out["c"] == data("C2"), "later source serves what earlier ones missed")
        #expect(out["d"] == nil)
    }

    @Test("Composite stops early once nothing is missing")
    func compositeStopsWhenSatisfied() async {
        let composite = CompositeContentSource([
            InMemoryContentSource(["a": data("A"), "b": data("B")]),
            InMemoryContentSource(["a": data("SHOULD-NOT-WIN")]),
        ])
        let out = await composite.fetch(["a", "b"])
        #expect(out["a"] == data("A"))
        #expect(out["b"] == data("B"))
    }
}
