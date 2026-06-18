import ArrayTrie

public extension MerkleArray {
    func mutating(at index: Int, value: ValueType) throws -> Self {
        guard index >= 0 && index < count else { throw TransformErrors.invalidKey("index \(index) out of bounds [0, \(count))") }
        return try mutating(key: Self.binaryKey(index), value: value)
    }

    func deleting(at index: Int) throws -> Self {
        guard index >= 0 && index < count else { throw TransformErrors.invalidKey("index \(index) out of bounds [0, \(count))") }
        let key = Self.binaryKey(index)
        let lastKey = Self.binaryKey(count - 1)
        if index == count - 1 {
            return try deleting(key: key)
        }
        guard let lastElement = try get(key: lastKey) else { throw TransformErrors.missingData("last element not found at index \(count - 1)") }
        var transforms = ArrayTrie<Transform>()
        transforms.set([key], value: .update(String(describing: lastElement)))
        transforms.set([lastKey], value: .delete)
        guard let result = try transform(transforms: transforms) else { throw TransformErrors.transformFailed("delete-and-swap transform failed at index \(index)") }
        return result
    }

    static func rangeTransforms(range: Range<Int>, transform: Transform) -> ArrayTrie<Transform> {
        var trie = ArrayTrie<Transform>()
        for i in range {
            trie.set([binaryKey(i)], value: transform)
        }
        return trie
    }
}

public extension MerkleArray where ValueType: Header, ValueType.NodeType: MerkleArray {
    static func nestedRangeTransforms(outerRange: Range<Int>, innerTransforms: [[String]: Transform]) -> ArrayTrie<Transform> {
        var trie = ArrayTrie<Transform>()
        for i in outerRange {
            let outerKey = binaryKey(i)
            for (innerPath, transform) in innerTransforms {
                trie.set([outerKey] + innerPath, value: transform)
            }
        }
        return trie
    }

    func transformNested(outerRange: Range<Int>, innerTransforms: [[String]: Transform], keyProvider: KeyProvider? = nil) throws -> Self? {
        let trie = Self.nestedRangeTransforms(outerRange: outerRange, innerTransforms: innerTransforms)
        return try transform(transforms: trie, keyProvider: keyProvider)
    }
}
