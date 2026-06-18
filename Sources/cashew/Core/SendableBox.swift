import ArrayTrie

/// Retroactive `Sendable` conformance for `ArrayTrie` when its values are `Sendable`.
/// Safe in cashew because tries are built once and then read concurrently.
extension ArrayTrie: @retroactive @unchecked Sendable where Value: Sendable {}

/// Wrapper that satisfies Swift 6 `sending` parameter requirements for task groups.
///
/// Even when a captured value is `Sendable`, `withThrowingTaskGroup.addTask`
/// rejects it if the variable is still accessible in the enclosing scope.
/// Boxing the value creates a new binding captured only by the closure.
struct SendableBox<T: Sendable>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
