import ArrayTrie
import Crypto

public extension Node {
    func encrypt(encryption: ArrayTrie<EncryptionStrategy>) throws -> Self {
        if encryption.isEmpty && encryption.get([]) == nil { return self }
        var newProperties: [PathSegment: any Header] = [:]
        for property in properties() {
            guard let address = get(property: property) else { continue }
            if let childEnc = encryption.traverse([property]) {
                newProperties[property] = try address.encrypt(encryption: childEnc)
            } else {
                newProperties[property] = address
            }
        }
        return set(properties: newProperties)
    }
}
