import Foundation
import Crypto

public extension Header {
    func storeRecursively(storer: Storer) throws {
        guard let node = node else {
            return
        }
        if storer.contains(rawCid: rawCID) {
            return
        }
        let dataToStore: Data
        if let info = encryptionInfo {
            guard let keyProvider = storer as? KeyProvider else { throw DataErrors.keyNotFound }
            guard let key = keyProvider.key(for: info.keyHash) else { throw DataErrors.keyNotFound }
            guard let ivData = info.ivData else { throw DataErrors.invalidIV }
            let nonce = try AES.GCM.Nonce(data: ivData)
            let plaintext = try Self.serializeNode(node, codec: Self.defaultCodec)
            dataToStore = try EncryptionHelper.encrypt(data: plaintext, key: key, nonce: nonce)
        } else {
            guard let nodeData = node.toData() else { throw DataErrors.serializationFailed }
            dataToStore = nodeData
        }
        try storer.store(rawCid: rawCID, data: dataToStore)
        try node.storeRecursively(storer: storer)
    }
}
