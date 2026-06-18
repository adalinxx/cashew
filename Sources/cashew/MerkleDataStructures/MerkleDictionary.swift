import ArrayTrie

/// A persistent, content-addressed key-value store backed by a compressed radix trie.
///
/// Keys are strings; values can be any `Codable & Sendable & LosslessStringConvertible` type.
/// Each mutation returns a new root that shares unchanged subtrees with the original,
/// and every node is identified by its CID (content hash).
///
/// Use ``MerkleDictionaryImpl`` as the concrete implementation.
public protocol MerkleDictionary: Node {
    associatedtype ValueType
    associatedtype ChildType: RadixHeader where ChildType.NodeType.ValueType == ValueType
    
    var children: [Character: ChildType] { get }
    var count: Int { get }
    
    init(children: [Character: ChildType], count: Int)
}

public extension MerkleDictionary {
    init() {
        self.init(children: [:], count: 0)
    }
    
    func get(property: PathSegment) -> (any Header)? {
        guard let char = property.first else { return nil }
        return children[char]
    }
    
    func properties() -> Set<PathSegment> {
        return Set(children.keys.map { String($0) })
    }
    
    func set(properties: [PathSegment: any Header]) -> Self {
        var newProperties = [Character: ChildType]()
        for property in properties {
            newProperties[property.key.first!] = property.value as? ChildType
        }
        return Self(children: newProperties, count: count)
    }
    
    func set(properties: [Character: ChildType]) -> Self {
        return Self(children: properties, count: count)
    }
    
    func allKeys() throws -> Set<String> {
        var keys = Set<String>()
        
        for (_, child) in children {
            guard let node = child.node else { throw DataErrors.nodeNotAvailable }
            try collectKeys(from: node, currentPath: "", into: &keys)
        }
        
        return keys
    }
    
    func allKeysAndValues() throws -> [String: ValueType] {
        var keysAndValues = [String: ValueType]()
        
        for (_, child) in children {
            guard let node = child.node else { throw DataErrors.nodeNotAvailable }
            try collectKeysAndValues(from: node, currentPath: "", into: &keysAndValues)
        }
        
        return keysAndValues
    }
    
    private func collectKeys(from node: ChildType.NodeType, currentPath: String, into keys: inout Set<String>) throws {
        let fullPath = currentPath + node.prefix
        
        // If this node has a value, it represents a complete key
        if node.value != nil {
            keys.insert(fullPath)
        }
        
        // Recursively traverse children
        for (_, child) in node.children {
            guard let childNode = child.node else { throw DataErrors.nodeNotAvailable }
            try collectKeys(from: childNode, currentPath: fullPath, into: &keys)
        }
    }
    
    private func collectKeysAndValues(from node: ChildType.NodeType, currentPath: String, into keysAndValues: inout [String: ValueType]) throws {
        let fullPath = currentPath + node.prefix

        // If this node has a value, it represents a complete key-value pair
        if let value = node.value {
            keysAndValues[fullPath] = value
        }

        // Recursively traverse children
        for (_, child) in node.children {
            guard let childNode = child.node else { throw DataErrors.nodeNotAvailable }
            try collectKeysAndValues(from: childNode, currentPath: fullPath, into: &keysAndValues)
        }
    }

    func sortedKeys(limit: Int = .max, after: String? = nil) throws -> [String] {
        var result = [String]()
        for char in children.keys.sorted() {
            guard let node = children[char]?.node else { throw DataErrors.nodeNotAvailable }
            try collectKeysSorted(from: node, currentPath: "", limit: limit, after: after, into: &result)
            if result.count >= limit { break }
        }
        return result
    }

    func sortedKeysAndValues(limit: Int = .max, after: String? = nil) throws -> [(key: String, value: ValueType)] {
        var result = [(key: String, value: ValueType)]()
        for char in children.keys.sorted() {
            guard let node = children[char]?.node else { throw DataErrors.nodeNotAvailable }
            try collectKeysAndValuesSorted(from: node, currentPath: "", limit: limit, after: after, into: &result)
            if result.count >= limit { break }
        }
        return result
    }

    private func collectKeysSorted(from node: ChildType.NodeType, currentPath: String, limit: Int, after: String?, into result: inout [String]) throws {
        guard result.count < limit else { return }
        let fullPath = currentPath + node.prefix

        if node.value != nil {
            if let after = after {
                if fullPath > after {
                    result.append(fullPath)
                }
            } else {
                result.append(fullPath)
            }
        }

        guard result.count < limit else { return }

        for char in node.children.keys.sorted() {
            guard let childNode = node.children[char]?.node else { throw DataErrors.nodeNotAvailable }
            try collectKeysSorted(from: childNode, currentPath: fullPath, limit: limit, after: after, into: &result)
            if result.count >= limit { return }
        }
    }

    private func collectKeysAndValuesSorted(from node: ChildType.NodeType, currentPath: String, limit: Int, after: String?, into result: inout [(key: String, value: ValueType)]) throws {
        guard result.count < limit else { return }
        let fullPath = currentPath + node.prefix

        if let value = node.value {
            if let after = after {
                if fullPath > after {
                    result.append((key: fullPath, value: value))
                }
            } else {
                result.append((key: fullPath, value: value))
            }
        }

        guard result.count < limit else { return }

        for char in node.children.keys.sorted() {
            guard let childNode = node.children[char]?.node else { throw DataErrors.nodeNotAvailable }
            try collectKeysAndValuesSorted(from: childNode, currentPath: fullPath, limit: limit, after: after, into: &result)
            if result.count >= limit { return }
        }
    }
}
