import Testing
@testable import Noum

@Suite("How Noum coaches trust copy")
struct HowNoumCoachesCopyTests {
    @Test("Trust surface names evidence boundaries without parity claims")
    func evidenceBoundaries() {
        let copy = ([
            HowNoumCoachesCopy.headline,
            HowNoumCoachesCopy.introduction,
            HowNoumCoachesCopy.limitationBody,
        ] + HowNoumCoachesCopy.principles.flatMap { [$0.title, $0.body] })
            .joined(separator: " ")
            .lowercased()

        #expect(copy.contains("your words"))
        #expect(copy.contains("repeated comparable reps"))
        #expect(copy.contains("cannot read motives"))
        #expect(copy.contains("qualified human coach"))
        #expect(!copy.contains("replaces a human coach"))
        #expect(!copy.contains("guaranteed"))
    }

    @Test("Trust principles have stable unique identifiers")
    func identifiers() {
        let ids = HowNoumCoachesCopy.principles.map(\.id)
        #expect(ids.count == 5)
        #expect(Set(ids).count == ids.count)
        #expect(HowNoumCoachesCopy.principles.allSatisfy { !$0.symbol.isEmpty })
    }
}
