import ArrayTrie

public extension MerkleArray {
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        let expanded = Self.expandRangePaths(paths, count: count)
        return try await resolvePaths(expanded, fetcher: fetcher)
    }

    static func rangePaths(_ range: Range<Int>) -> ArrayTrie<ResolutionStrategy> {
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set([], value: rangeStrategy(range))
        return paths
    }

    static func rangePaths(_ range: Range<Int>, innerStrategy: ResolutionStrategy) -> ArrayTrie<ResolutionStrategy> {
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set([], value: rangeStrategy(range))
        for i in range {
            paths.set([binaryKey(i)], value: innerStrategy)
        }
        return paths
    }

    static func rangePaths(_ range: Range<Int>, innerRange: Range<Int>) -> ArrayTrie<ResolutionStrategy> {
        return rangePaths(range, innerStrategy: rangeStrategy(innerRange))
    }

    static func rangeStrategy(_ range: Range<Int>) -> ResolutionStrategy {
        let after: String? = range.lowerBound > 0 ? binaryKey(range.lowerBound - 1) : nil
        return .range(after: after, limit: range.count)
    }

    private static func decodeBinaryKey(_ key: String) -> Int {
        var result = 0
        for c in key {
            result = result * 2 + (c == "1" ? 1 : 0)
        }
        return result
    }

    private static func expandRangePaths(_ paths: ArrayTrie<ResolutionStrategy>, count: Int) -> ArrayTrie<ResolutionStrategy> {
        var expanded = paths
        if case .range(let after, let limit) = paths.get([]) {
            expanded = expanded.deleting(path: [])
            let startIndex: Int
            if let after = after {
                startIndex = decodeBinaryKey(after) + 1
            } else {
                startIndex = 0
            }
            let endIndex = min(startIndex + limit, count)
            guard startIndex < endIndex else { return expanded }
            for i in startIndex..<endIndex {
                let key = binaryKey(i)
                if expanded.get([key]) == nil {
                    expanded.set([key], value: .list)
                }
            }
        }
        return expanded
    }
}
