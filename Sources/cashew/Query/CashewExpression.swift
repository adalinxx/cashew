public enum CashewExpression: Equatable, Sendable {
    case get(String)
    case getAt(Int)
    case keys
    case sortedKeys(limit: Int?, after: String?)
    case values
    case sortedValues(limit: Int?, after: String?)
    case count
    case contains(String)
    case first
    case last
    case insert(key: String, value: String)
    case update(key: String, value: String)
    case set(key: String, value: String)
    case delete(String)
    case append(String)
}

public struct AnyQueryable: Sendable {
    private let _execute: @Sendable (CashewPlan) throws -> CashewResult
    private let _executeAsync: @Sendable (CashewPlan, Fetcher) async throws -> CashewResult
    public let description: String

    public init<T: CashewQueryable & Sendable>(_ value: T) {
        _execute = { plan in try value.execute(plan: plan).1 }
        _executeAsync = { plan, fetcher in try await value.execute(plan: plan, fetcher: fetcher).1 }
        description = "\(value)"
    }

    public func execute(plan: CashewPlan) throws -> CashewResult {
        try _execute(plan)
    }

    public func execute(plan: CashewPlan, fetcher: Fetcher) async throws -> CashewResult {
        try await _executeAsync(plan, fetcher)
    }
}

public enum CashewResult: Sendable, CustomStringConvertible {
    case value(String?)
    case bool(Bool)
    case count(Int)
    case list([String])
    case entries([(key: String, value: String)])
    case node(AnyQueryable)
    case ok

    public var description: String {
        switch self {
        case .value(let v): return v ?? "nil"
        case .bool(let b): return b ? "true" : "false"
        case .count(let n): return "\(n)"
        case .list(let items): return items.joined(separator: "\n")
        case .entries(let pairs): return pairs.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        case .node(let q): return q.description
        case .ok: return "ok"
        }
    }
}

extension CashewResult: Equatable {
    public static func == (lhs: CashewResult, rhs: CashewResult) -> Bool {
        switch (lhs, rhs) {
        case (.value(let a), .value(let b)): return a == b
        case (.bool(let a), .bool(let b)): return a == b
        case (.count(let a), .count(let b)): return a == b
        case (.list(let a), .list(let b)): return a == b
        case (.entries(let a), .entries(let b)):
            guard a.count == b.count else { return false }
            return zip(a, b).allSatisfy { $0.key == $1.key && $0.value == $1.value }
        case (.ok, .ok): return true
        case (.node, .node): return false
        default: return false
        }
    }
}

public enum CashewQueryError: Error, Equatable {
    case parseError(String)
    case invalidValue(String)
    case emptyExpression
    case unsupportedOperation(String)
}
