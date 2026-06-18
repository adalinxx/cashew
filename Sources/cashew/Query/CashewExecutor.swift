import ArrayTrie

func wrapQueryable(_ header: any Header) -> AnyQueryable {
    func open<H: Header>(_ h: H) -> AnyQueryable { AnyQueryable(h) }
    return open(header)
}

public extension Node {
    func defaultEvaluate(_ expression: CashewExpression) throws -> (Self, CashewResult) {
        switch expression {
        case .get(let key):
            guard let header = get(property: key) else { return (self, .value(nil)) }
            return (self, .node(wrapQueryable(header)))

        case .count:
            return (self, .count(properties().count))

        case .keys:
            return (self, .list(Array(properties())))

        case .sortedKeys(let limit, let after):
            var keys = properties().sorted()
            if let after = after {
                keys = keys.filter { $0 > after }
            }
            return (self, .list(Array(keys.prefix(limit ?? .max))))

        case .contains(let key):
            return (self, .bool(get(property: key) != nil))

        case .set(let key, let value):
            let op: Transform = get(property: key) != nil ? .update(value) : .insert(value)
            var trie = ArrayTrie<Transform>()
            trie.set([key], value: op)
            guard let result = try transform(transforms: trie) else {
                throw CashewQueryError.unsupportedOperation("Transform produced empty result")
            }
            return (result, .ok)

        case .insert, .update, .delete:
            throw CashewQueryError.unsupportedOperation("Transforms should be compiled into ArrayTrie steps")

        default:
            throw CashewQueryError.unsupportedOperation("Expression \(expression) not supported by \(type(of: self))")
        }
    }

    func evaluate(_ expression: CashewExpression) throws -> (Self, CashewResult) {
        try defaultEvaluate(expression)
    }

    func execute(plan: CashewPlan) throws -> (Self, CashewResult) {
        var current = self
        var lastResult: CashewResult = .ok

        for (index, step) in plan.steps.enumerated() {
            switch step {
            case .transform(let trie):
                guard let transformed = try current.transform(transforms: trie) else {
                    throw CashewQueryError.unsupportedOperation("Transform produced empty result")
                }
                current = transformed
                lastResult = .ok

            case .evaluate(let expr):
                let hasRemaining = index < plan.steps.count - 1

                if case .get(let key) = expr, hasRemaining, let header = current.get(property: key) {
                    let remaining = CashewPlan(steps: Array(plan.steps[(index + 1)...]))
                    lastResult = try wrapQueryable(header).execute(plan: remaining)
                    return (current, lastResult)
                }

                let (next, result) = try current.evaluate(expr)
                current = next
                lastResult = result

                if case .node(let child) = result {
                    let remaining = CashewPlan(steps: Array(plan.steps[(index + 1)...]))
                    if !remaining.steps.isEmpty {
                        lastResult = try child.execute(plan: remaining)
                    }
                    return (current, lastResult)
                }
            }
        }

        return (current, lastResult)
    }

    func query(_ input: String) throws -> (Self, CashewResult) {
        let expressions = try CashewParser.parse(input)
        let plan = CashewPlan.compile(expressions)
        return try execute(plan: plan)
    }

    func execute(_ expression: CashewExpression) throws -> (Self, CashewResult) {
        let plan = CashewPlan.compile([expression])
        return try execute(plan: plan)
    }

    func query(_ input: String, fetcher: Fetcher) async throws -> (Self, CashewResult) {
        let expressions = try CashewParser.parse(input)
        let plan = CashewPlan.compile(expressions)
        return try await execute(plan: plan, fetcher: fetcher)
    }

    func execute(_ expression: CashewExpression, fetcher: Fetcher) async throws -> (Self, CashewResult) {
        let plan = CashewPlan.compile([expression])
        return try await execute(plan: plan, fetcher: fetcher)
    }

    func execute(plan: CashewPlan, fetcher: Fetcher) async throws -> (Self, CashewResult) {
        return try execute(plan: plan)
    }
}

// MARK: - MerkleDictionary overrides

func evaluateExpression<D: MerkleDictionary>(
    _ dict: D,
    _ expression: CashewExpression
) throws -> (D, CashewResult) where D.ValueType: LosslessStringConvertible {
    switch expression {
    case .get(let key):
        let value = try dict.get(key: key)
        if let header = value as? any Header {
            return (dict, .node(wrapQueryable(header)))
        }
        return (dict, .value(value.map { "\($0)" }))

    case .keys:
        return (dict, .list(Array(try dict.allKeys())))

    case .sortedKeys(let limit, let after):
        return (dict, .list(try dict.sortedKeys(limit: limit ?? .max, after: after)))

    case .values:
        let kvs = try dict.allKeysAndValues()
        return (dict, .entries(kvs.map { (key: $0.key, value: "\($0.value)") }))

    case .sortedValues(let limit, let after):
        let pairs = try dict.sortedKeysAndValues(limit: limit ?? .max, after: after)
        return (dict, .entries(pairs.map { (key: $0.key, value: "\($0.value)") }))

    case .count:
        return (dict, .count(dict.count))

    case .contains(let key):
        return (dict, .bool(try dict.get(key: key) != nil))

    case .set(let key, let value):
        guard let _ = D.ValueType(value) else {
            throw CashewQueryError.invalidValue(value)
        }
        let op: Transform = try dict.get(key: key) != nil ? .update(value) : .insert(value)
        var trie = ArrayTrie<Transform>()
        trie.set([key], value: op)
        guard let result = try dict.transform(transforms: trie) else {
            return (D(), .ok)
        }
        return (result, .ok)

    case .insert, .update, .delete:
        throw CashewQueryError.unsupportedOperation("Transforms should be compiled into ArrayTrie steps")

    case .getAt, .first, .last, .append:
        throw CashewQueryError.unsupportedOperation("Array operations require MerkleArray")
    }
}

public extension MerkleDictionary where ValueType: LosslessStringConvertible {
    func evaluate(_ expression: CashewExpression) throws -> (Self, CashewResult) {
        return try evaluateExpression(self, expression)
    }

    func execute(plan: CashewPlan) throws -> (Self, CashewResult) {
        var current = self
        var lastResult: CashewResult = .ok

        for (index, step) in plan.steps.enumerated() {
            switch step {
            case .transform(let trie):
                if let transformed = try current.transform(transforms: trie) {
                    current = transformed
                } else {
                    current = Self()
                }
                lastResult = .ok

            case .evaluate(let expr):
                let (next, result) = try current.evaluate(expr)
                current = next
                lastResult = result

                if case .node(let child) = result {
                    let remaining = CashewPlan(steps: Array(plan.steps[(index + 1)...]))
                    if !remaining.steps.isEmpty {
                        lastResult = try child.execute(plan: remaining)
                    }
                    return (current, lastResult)
                }
            }
        }

        return (current, lastResult)
    }

    func execute(plan: CashewPlan, fetcher: Fetcher) async throws -> (Self, CashewResult) {
        let paths = plan.resolutionPaths()
        let resolved = try await self.resolve(paths: paths, fetcher: fetcher)
        return try resolved.execute(plan: plan)
    }
}

// MARK: - MerkleArray overrides

public extension MerkleArray where ValueType: LosslessStringConvertible {
    func evaluate(_ expression: CashewExpression) throws -> (Self, CashewResult) {
        switch expression {
        case .getAt(let index):
            let value = try get(at: index)
            return (self, .value(value.map { "\($0)" }))

        case .first:
            let value = try first()
            return (self, .value(value.map { "\($0)" }))

        case .last:
            let value = try last()
            return (self, .value(value.map { "\($0)" }))

        case .append(let value):
            guard let _ = ValueType(value) else {
                throw CashewQueryError.invalidValue(value)
            }
            var trie = ArrayTrie<Transform>()
            trie.set([Self.binaryKey(count)], value: .insert(value))
            if let transformed = try transform(transforms: trie) {
                return (transformed, .ok)
            }
            return (self, .ok)

        default:
            return try evaluateExpression(self, expression)
        }
    }

}

// MARK: - Header delegation

public extension Header {
    private func withNode(_ body: (NodeType) throws -> (NodeType, CashewResult)) throws -> (Self, CashewResult) {
        guard let node = node else { throw DataErrors.nodeNotAvailable }
        let (updatedNode, result) = try body(node)
        return (try Self(node: updatedNode), result)
    }

    private func withResolvedNode(fetcher: Fetcher, _ body: (NodeType) async throws -> (NodeType, CashewResult)) async throws -> (Self, CashewResult) {
        let loaded = node != nil ? self : try await resolve(fetcher: fetcher)
        guard let loadedNode = loaded.node else { throw DataErrors.nodeNotAvailable }
        let (updatedNode, result) = try await body(loadedNode)
        return (try Self(node: updatedNode), result)
    }

    func evaluate(_ expression: CashewExpression) throws -> (Self, CashewResult) {
        try withNode { try $0.evaluate(expression) }
    }

    func query(_ input: String) throws -> (Self, CashewResult) {
        try withNode { try $0.query(input) }
    }

    func execute(plan: CashewPlan) throws -> (Self, CashewResult) {
        try withNode { try $0.execute(plan: plan) }
    }

    func execute(_ expression: CashewExpression) throws -> (Self, CashewResult) {
        try withNode { try $0.execute(expression) }
    }

    func query(_ input: String, fetcher: Fetcher) async throws -> (Self, CashewResult) {
        try await withResolvedNode(fetcher: fetcher) { try await $0.query(input, fetcher: fetcher) }
    }

    func execute(plan: CashewPlan, fetcher: Fetcher) async throws -> (Self, CashewResult) {
        try await withResolvedNode(fetcher: fetcher) { try await $0.execute(plan: plan, fetcher: fetcher) }
    }

    func execute(_ expression: CashewExpression, fetcher: Fetcher) async throws -> (Self, CashewResult) {
        try await withResolvedNode(fetcher: fetcher) { try await $0.execute(plan: CashewPlan.compile([expression]), fetcher: fetcher) }
    }
}
