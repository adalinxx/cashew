public extension RadixHeader {
    func get(key: ArraySlice<Character>) throws -> NodeType.ValueType? {
        guard let node = node else { throw TransformErrors.missingData("node not loaded") }
        return try node.get(key: key)
    }
    
    func deleting(key: ArraySlice<Character>) throws -> Self? {
        guard let node = node else { throw TransformErrors.missingData("node not loaded") }
        if let newNode = try node.deleting(key: key) {
            return try Self(node: newNode)
        }
        return nil
    }
    
    func inserting(key: ArraySlice<Character>, value: NodeType.ValueType) throws -> Self {
        guard let node = node else { throw TransformErrors.missingData("node not loaded") }
        let newNode = try node.inserting(key: key, value: value)
        return try Self(node: newNode)
    }
    
    func mutating(key: ArraySlice<Character>, value: NodeType.ValueType) throws -> Self {
        guard let node = node else { throw TransformErrors.missingData("node not loaded") }
        let newNode = try node.mutating(key: key, value: value)
        return try Self(node: newNode)
    }

    func deleting(key: ArraySlice<Character>, keyProvider: KeyProvider?) throws -> Self? {
        guard let node = node else { throw TransformErrors.missingData("node not loaded") }
        if let newNode = try node.deleting(key: key) {
            return try reEncryptIfNeeded(node: newNode, keyProvider: keyProvider)
        }
        return nil
    }

    func mutating(key: ArraySlice<Character>, value: NodeType.ValueType, keyProvider: KeyProvider?) throws -> Self {
        guard let node = node else { throw TransformErrors.missingData("node not loaded") }
        let newNode = try node.mutating(key: key, value: value)
        return try reEncryptIfNeeded(node: newNode, keyProvider: keyProvider)
    }
}
