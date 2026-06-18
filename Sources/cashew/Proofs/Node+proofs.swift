import ArrayTrie

public extension Node {
    func proof(paths: ArrayTrie<SparseMerkleProof>, fetcher: Fetcher) async throws -> Self {
        let rootValue = paths.get([])
        if rootValue != nil && rootValue != .mutation && rootValue != .existence { throw ProofErrors.invalidProofType("root proof type must be .mutation or .existence") }
        if paths.childCharacters().count == 0 { return self }

        let childKeys = paths.childKeys()
        let allProperties = Set(childKeys).union(properties())
        let box = SendableBox(paths)
        let newProperties = try await withThrowingTaskGroup(of: (PathSegment, any Header)?.self) { group in
            for property in allProperties {
                group.addTask {
                    let paths = box.value
                    guard let address = get(property: property) else {
                        if childKeys.contains(property) { throw ProofErrors.invalidProofType("proof references non-existent property '\(property)'") }
                        return nil
                    }
                    let valueAtPaths = paths.get([property])
                    if valueAtPaths != nil && valueAtPaths != .mutation && valueAtPaths != .existence { throw ProofErrors.invalidProofType("child proof type must be .mutation or .existence for '\(property)'") }
                    guard let nextPaths = paths.traverse([property]) else {
                        return (property, address)
                    }
                    if nextPaths.isEmpty {
                        return (property, address)
                    }
                    let resolved = try await address.proof(paths: nextPaths, fetcher: fetcher)
                    return (property, resolved)
                }
            }
            var result = [PathSegment: any Header]()
            for try await pair in group {
                if let (key, value) = pair {
                    result[key] = value
                }
            }
            return result
        }
        return set(properties: newProperties)
    }
}
