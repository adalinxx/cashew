import ArrayTrie

public extension MerkleDictionary {
    func resolve(paths: [[String]: ResolutionStrategy], fetcher: Fetcher) async throws -> Self {
        if paths.isEmpty { return self }
        var pathTrie = ArrayTrie<ResolutionStrategy>()
        for (path, strategy) in paths {
            pathTrie.set(path, value: strategy)
        }
        return try await resolve(paths: pathTrie, fetcher: fetcher)
    }

    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        return try await resolvePaths(paths, fetcher: fetcher)
    }

    func resolvePaths(_ paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        if paths.get([""]) == .recursive {
            return try await resolveRecursive(fetcher: fetcher)
        }
        if case .range(let after, _) = paths.get([""]) {
            let afterFirstChar = after?.first
            let newProperties = try await resolveChildrenConcurrently { char in
                if let afterChar = afterFirstChar, char < afterChar {
                    return children[char]!
                }
                if let childPath = paths.traverseChild(char) {
                    return try await children[char]!.resolveList(paths: childPath, fetcher: fetcher)
                } else {
                    return try await children[char]!.resolveList(paths: ArrayTrie(), fetcher: fetcher)
                }
            }
            return Self(children: newProperties, count: count)
        }
        if paths.get([""]) == .list {
            let newProperties = try await resolveChildrenConcurrently { char in
                if let childPath = paths.traverseChild(char) {
                    return try await children[char]!.resolveList(paths: childPath, fetcher: fetcher)
                } else {
                    return try await children[char]!.resolveList(paths: ArrayTrie(), fetcher: fetcher)
                }
            }
            return Self(children: newProperties, count: count)
        }
        else {
            let newProperties = try await resolveChildrenConcurrently { char in
                if let childPath = paths.traverseChild(char) {
                    return try await children[char]!.resolve(paths: childPath, fetcher: fetcher)
                } else {
                    return children[char]!
                }
            }
            return Self(children: newProperties, count: count)
        }
    }

    func resolveList(fetcher: Fetcher) async throws -> Self {
        let newProperties = try await resolveChildrenConcurrently { char in
            try await children[char]!.resolveList(paths: ArrayTrie(), fetcher: fetcher)
        }
        return Self(children: newProperties, count: count)
    }

    static func rangePaths(after: String? = nil, limit: Int) -> ArrayTrie<ResolutionStrategy> {
        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set([""], value: .range(after: after, limit: limit))
        return paths
    }

    func resolve(fetcher: Fetcher) async throws -> Self {
        return self
    }

    private func resolveChildrenConcurrently(_ resolve: @Sendable @escaping (Character) async throws -> ChildType) async throws -> [Character: ChildType] {
        try await withThrowingTaskGroup(of: (Character, ChildType).self) { group in
            for property in properties() {
                let char = property.first!
                group.addTask {
                    let resolved = try await resolve(char)
                    return (char, resolved)
                }
            }
            var result = [Character: ChildType]()
            for try await (key, value) in group {
                result[key] = value
            }
            return result
        }
    }
}
