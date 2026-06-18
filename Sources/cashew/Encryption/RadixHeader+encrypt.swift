import ArrayTrie
import Crypto

public extension RadixHeader {
    func encrypt(encryption: ArrayTrie<EncryptionStrategy>) throws -> Self {
        guard let node = node else { throw DataErrors.nodeNotAvailable }
        let encryptedNode = try node.encrypt(encryption: encryption)
        return try Self(node: encryptedNode)
    }

    func encryptWithStrategy(_ strategy: EncryptionStrategy, overrides: ArrayTrie<EncryptionStrategy>?) throws -> Self {
        guard let node = node else { throw DataErrors.nodeNotAvailable }
        let encryptedNode = try node.encryptWithStrategy(strategy, overrides: overrides)
        return try Self(node: encryptedNode, key: strategy.key)
    }
}
