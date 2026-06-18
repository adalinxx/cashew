import ArrayTrie

public protocol CashewQueryable {
    func evaluate(_ expression: CashewExpression) throws -> (Self, CashewResult)
    func execute(plan: CashewPlan) throws -> (Self, CashewResult)
    func execute(plan: CashewPlan, fetcher: Fetcher) async throws -> (Self, CashewResult)
}
