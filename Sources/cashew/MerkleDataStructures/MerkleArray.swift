import ArrayTrie

/// An append-only ordered collection backed by a ``MerkleDictionary``.
///
/// Elements are stored under 256-bit binary keys derived from their integer index,
/// which preserves lexicographic ordering in the underlying radix trie and enables
/// efficient range queries.
public protocol MerkleArray: MerkleDictionary {}

public extension MerkleArray {
    static func binaryKey(_ index: Int) -> String {
        var chars = [Character](repeating: "0", count: 256)
        var val = index
        var pos = 255
        while val > 0 && pos >= 0 {
            if val & 1 == 1 {
                chars[pos] = "1"
            }
            val >>= 1
            pos -= 1
        }
        return String(chars)
    }

    func get(at index: Int) throws -> ValueType? {
        guard index >= 0 && index < count else { return nil }
        return try get(key: Self.binaryKey(index))
    }

    func append(_ element: ValueType) throws -> Self {
        return try inserting(key: Self.binaryKey(count), value: element)
    }

    func append(contentsOf other: Self) throws -> Self {
        var result = self
        for i in 0..<other.count {
            guard let element = try other.get(at: i) else { throw DataErrors.nodeNotAvailable }
            result = try result.append(element)
        }
        return result
    }

    func first() throws -> ValueType? {
        guard count > 0 else { return nil }
        return try get(at: 0)
    }

    func last() throws -> ValueType? {
        guard count > 0 else { return nil }
        return try get(at: count - 1)
    }
}
