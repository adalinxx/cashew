public extension Header {
    func diff(from old: Self) -> CashewDiff {
        if rawCID == old.rawCID { return CashewDiff() }
        guard let oldNode = old.node, let newNode = node else {
            return CashewDiff()
        }
        return newNode.diff(from: oldNode)
    }

    func diff(from old: Self, fetcher: Fetcher) async throws -> CashewDiff {
        if rawCID == old.rawCID { return CashewDiff() }
        let resolvedOld = try await old.resolveRecursive(fetcher: fetcher)
        let resolvedNew = try await self.resolveRecursive(fetcher: fetcher)
        return resolvedNew.diff(from: resolvedOld)
    }
}

public extension Header where NodeType: MerkleDictionary, NodeType.ValueType: LosslessStringConvertible {
    func diff(from old: Self) throws -> CashewDiff {
        if rawCID == old.rawCID { return CashewDiff() }
        guard let oldNode = old.node, let newNode = node else {
            return CashewDiff()
        }
        return try newNode.diff(from: oldNode)
    }

    func diff(from old: Self, fetcher: Fetcher) async throws -> CashewDiff {
        if rawCID == old.rawCID { return CashewDiff() }
        let resolvedOld = try await old.resolveRecursive(fetcher: fetcher)
        let resolvedNew = try await self.resolveRecursive(fetcher: fetcher)
        return try resolvedNew.diff(from: resolvedOld)
    }
}
