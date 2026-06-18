import ArrayTrie
import Crypto

public extension Header {
    func encrypt(encryption: ArrayTrie<EncryptionStrategy>, key: SymmetricKey) throws -> Self {
        guard let node = node else { throw DataErrors.nodeNotAvailable }
        let encryptedNode = try node.encrypt(encryption: encryption)
        return try Self(node: encryptedNode, key: key)
    }
}
