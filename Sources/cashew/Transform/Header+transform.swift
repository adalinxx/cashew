import ArrayTrie

public extension Header {
    func transform(transforms: [[String]: Transform]) throws -> Self? {
        var trieRepresentation = ArrayTrie<Transform>()
        for path in transforms {
            trieRepresentation.set(path.key, value: path.value)
        }
        return try transform(transforms: trieRepresentation)
    }

    func transform(transforms: ArrayTrie<Transform>, encryption: ArrayTrie<EncryptionStrategy>, keyProvider: KeyProvider? = nil) throws -> Self? {
        guard let transformed = try transform(transforms: transforms, keyProvider: keyProvider) else { return nil }
        if encryption.isEmpty && encryption.get([]) == nil { return transformed }
        return try transformed.encrypt(encryption: encryption)
    }
}
