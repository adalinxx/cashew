import ArrayTrie

public extension Node {
    func transform(transforms: ArrayTrie<Transform>) throws -> Self? {
        return try transform(transforms: transforms, keyProvider: nil)
    }

    func transform(transforms: ArrayTrie<Transform>, keyProvider: KeyProvider?) throws -> Self? {
        if transforms.isEmpty { return self }
        switch transforms.get([]) {
            case .update(let newNodeString):
                guard let updatedNode = Self(newNodeString) else { throw TransformErrors.transformFailed("failed to parse updated node") }
                return try updatedNode.transformAfterUpdate(transforms: transforms, keyProvider: keyProvider)
            default: return try transformAfterUpdate(transforms: transforms, keyProvider: keyProvider)
        }
    }

    func transformAfterUpdate(transforms: ArrayTrie<Transform>) throws -> Self? {
        return try transformAfterUpdate(transforms: transforms, keyProvider: nil)
    }

    func transformAfterUpdate(transforms: ArrayTrie<Transform>, keyProvider: KeyProvider?) throws -> Self? {
        var newProperties: [PathSegment: any Header] = [:]

        let allChildKeys = Set(transforms.childKeys()).union(properties())

        for childKey in allChildKeys {
            guard let address = get(property: childKey) else { throw TransformErrors.transformFailed("missing property '\(childKey)'") }
            if let newTransforms = transforms.traverse([childKey]) {
                guard let newAddress = try address.transform(transforms: newTransforms, keyProvider: keyProvider) else { throw TransformErrors.transformFailed("transform returned nil for '\(childKey)'") }
                newProperties[childKey] = newAddress
            }
            else {
                newProperties[childKey] = address
            }
        }

        return set(properties: newProperties)
    }
}
