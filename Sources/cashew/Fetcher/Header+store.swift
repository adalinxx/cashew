import Foundation
import Crypto

extension Header {
    /// Serialize this materialized Header exactly as its CID was computed.
    ///
    /// Both ordinary Header storage and Volume-root storage use this helper so
    /// plaintext/encrypted paths cannot drift apart.
    func serializedDataForStorage(storer: Storer) throws -> Data {
        guard let node else { throw DataErrors.nodeNotAvailable }

        if let info = encryptionInfo {
            guard let keyProvider = storer as? KeyProvider else { throw DataErrors.keyNotFound }
            guard let key = keyProvider.key(for: info.keyHash) else { throw DataErrors.keyNotFound }
            guard let ivData = info.ivData else { throw DataErrors.invalidIV }
            let nonce = try AES.GCM.Nonce(data: ivData)
            let plaintext = try Self.serializeNode(node, codec: Self.defaultCodec)
            return try EncryptionHelper.encrypt(data: plaintext, key: key, nonce: nonce)
        }

        guard let nodeData = node.toData() else { throw DataErrors.serializationFailed }
        return nodeData
    }

    /// Store one ordinary Header and every ordinary descendant inside the
    /// currently active Volume boundary, stopping at nested Volume boundaries.
    ///
    /// The returned materialized nested Volumes are stored independently only after
    /// the current boundary has successfully exited.
    func storeWithinCurrentVolume(storer: VolumeAwareStorer) throws -> [any Header] {
        guard let node else { throw DataErrors.nodeNotAvailable }
        try storer.store(rawCid: rawCID, data: try serializedDataForStorage(storer: storer))
        return try node.storeWithinCurrentVolume(storer: storer)
    }
}

public extension Header {
    func storeRecursively(storer: Storer) throws {
        guard let node else { return }
        if storer.contains(rawCid: rawCID) { return }

        try storer.store(rawCid: rawCID, data: try serializedDataForStorage(storer: storer))
        try node.storeRecursively(storer: storer)
    }
}
