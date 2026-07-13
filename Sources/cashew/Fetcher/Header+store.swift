import Foundation
import Crypto

public extension Header {
    func storeRecursively(storer: Storer) throws {
        let volumeAware = storer as? VolumeAwareStorer

        guard let node = node else {
            // A Volume-aware walk is constructing one complete availability unit.
            // Every ordinary Header reached through Node.properties() is therefore
            // owned by the current Volume boundary and must be materialized so its
            // bytes and owned descendants can be included. Plain Storers retain the
            // historical best-effort behavior for callers intentionally persisting
            // only the materialized portion of a generic Header graph.
            if volumeAware != nil {
                throw DataErrors.nodeNotAvailable
            }
            return
        }

        // `contains` answers whether the bytes already exist, not whether this CID
        // has been recorded as a member of the Volume currently being traversed.
        // A VolumeAwareStorer must observe `store` for every owned node in every
        // boundary; it may deduplicate the underlying bytes internally.
        if volumeAware == nil, storer.contains(rawCid: rawCID) {
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
