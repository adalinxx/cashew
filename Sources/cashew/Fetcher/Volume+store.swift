import Crypto
import Foundation

public extension Volume {
    func storeRecursively(storer: Storer) throws {
        // Calling storage on a Volume root is a request to publish that complete
        // availability unit. An unresolved root cannot be published. Unresolved
        // nested Volumes are skipped by Node.storeRecursively because each nested
        // boundary is an independent availability unit.
        guard let node = node else { throw DataErrors.nodeNotAvailable }

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

        if let volumeAware = storer as? VolumeAwareStorer {
            try volumeAware.enterVolume(rootCID: rawCID)
            do {
                try volumeAware.store(rawCid: rawCID, data: dataToStore)
                try node.storeRecursively(storer: volumeAware)
                try volumeAware.exitVolume(rootCID: rawCID)
            } catch {
                // A failed walk must never leave a scope that can later be flushed
                // as though it were a complete Volume. Preserve the original error.
                volumeAware.abortVolume(rootCID: rawCID)
                throw error
            }
        } else {
            try storer.store(rawCid: rawCID, data: dataToStore)
            try node.storeRecursively(storer: storer)
        }
    }
}
