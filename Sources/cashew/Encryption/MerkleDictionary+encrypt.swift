import ArrayTrie
import Crypto

public extension MerkleDictionary {
    func encrypt(encryption: ArrayTrie<EncryptionStrategy>) throws -> Self {
        if let rootStrategy = encryption.get([""]) {
            return try encryptWithStrategy(rootStrategy, overrides: encryption)
        }
        var newChildren = children
        for (char, child) in children {
            if let childEnc = encryption.traverseChild(char) {
                newChildren[char] = try child.encrypt(encryption: childEnc)
            }
        }
        return Self(children: newChildren, count: count)
    }

    func encryptWithStrategy(_ strategy: EncryptionStrategy, overrides: ArrayTrie<EncryptionStrategy>) throws -> Self {
        var newChildren = [Character: ChildType]()
        for (char, child) in children {
            let childOverrides = overrides.traverseChild(char)
            switch strategy {
            case .recursive:
                if let childOverrides, !childOverrides.allValues().isEmpty {
                    newChildren[char] = try child.encryptRecursiveWithOverrides(key: strategy.key, overrides: childOverrides)
                } else {
                    newChildren[char] = try child.encryptWithStrategy(strategy, overrides: childOverrides)
                }
            case .list, .targeted:
                newChildren[char] = try child.encryptWithStrategy(strategy, overrides: childOverrides)
            }
        }
        return Self(children: newChildren, count: count)
    }
}
