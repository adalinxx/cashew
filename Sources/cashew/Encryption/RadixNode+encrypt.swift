import ArrayTrie
import Crypto

public extension RadixNode {
    func encrypt(encryption: ArrayTrie<EncryptionStrategy>) throws -> Self {
        let strategy = encryption.get([prefix]) ?? encryption.valuesAlongPath(prefix).last?.1
        if let strategy {
            let remaining = encryption.traverse(path: prefix)
            return try encryptWithStrategy(strategy, overrides: remaining)
        }

        guard let traversed = encryption.traverse(path: prefix) else { return self }
        var newChildren = children
        for (char, child) in children {
            if let childEnc = traversed.traverseChild(char) {
                newChildren[char] = try child.encrypt(encryption: childEnc)
            }
        }
        return Self(prefix: prefix, value: value, children: newChildren)
    }

    func encryptWithStrategy(_ strategy: EncryptionStrategy, overrides: ArrayTrie<EncryptionStrategy>?) throws -> Self {
        let key = strategy.key
        var newChildren = [Character: ChildType]()

        for (char, child) in children {
            let childOverrides = overrides?.traverseChild(char)
            switch strategy {
            case .list:
                newChildren[char] = try child.encryptWithStrategy(strategy, overrides: childOverrides)
            case .recursive, .targeted:
                if let childOverrides, !childOverrides.allValues().isEmpty {
                    newChildren[char] = try child.encryptRecursiveWithOverrides(key: key, overrides: childOverrides)
                } else {
                    newChildren[char] = try child.encryptWithStrategy(strategy, overrides: nil)
                }
            }
        }

        switch strategy {
        case .recursive:
            if let value = value as? any Header {
                let valueOverrides = overrides?.traverse([""])
                if let valueOverrides, !valueOverrides.isEmpty {
                    guard let encrypted = try value.encrypt(encryption: valueOverrides).encryptSelf(key: key) as? ValueType else {
                        throw DataErrors.encryptionFailed
                    }
                    return Self(prefix: prefix, value: encrypted, children: newChildren)
                }
                guard let encrypted = try value.encryptSelf(key: key) as? ValueType else {
                    throw DataErrors.encryptionFailed
                }
                return Self(prefix: prefix, value: encrypted, children: newChildren)
            }
        case .targeted:
            if overrides?.get([""]) != nil, let value = value as? any Header {
                guard let encrypted = try value.encryptSelf(key: key) as? ValueType else {
                    throw DataErrors.encryptionFailed
                }
                return Self(prefix: prefix, value: encrypted, children: newChildren)
            }
        case .list:
            break
        }

        return Self(prefix: prefix, value: value, children: newChildren)
    }
}

extension RadixHeader {
    func encryptRecursiveWithOverrides(key: SymmetricKey, overrides: ArrayTrie<EncryptionStrategy>) throws -> Self {
        guard let node = node else { throw DataErrors.nodeNotAvailable }

        let override = overrides.get([node.prefix]) ?? overrides.valuesAlongPath(node.prefix).last?.1
        if let override {
            let remaining = overrides.traverse(path: node.prefix)
            let encryptedNode = try node.encryptWithStrategy(override, overrides: remaining)
            return try Self(node: encryptedNode, key: override.key)
        }

        let traversed = overrides.traverse(path: node.prefix)
        let encryptedNode = try node.encryptWithStrategy(.recursive(key), overrides: (traversed?.allValues().isEmpty ?? true) ? nil : traversed)
        return try Self(node: encryptedNode, key: key)
    }
}
