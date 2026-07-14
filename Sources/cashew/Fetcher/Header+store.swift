import ArrayTrie
import Foundation
import Crypto

extension Header {
    /// Serialize this materialized Header exactly as its CID was computed.
    func serializedDataForStorage(keyProvider: (any KeyProvider)?) throws -> Data {
        guard let node else { throw DataErrors.nodeNotAvailable }

        let data: Data
        if let info = encryptionInfo {
            guard let keyProvider else { throw DataErrors.keyNotFound }
            guard let key = keyProvider.key(for: info.keyHash) else { throw DataErrors.keyNotFound }
            guard let ivData = info.ivData else { throw DataErrors.invalidIV }
            let nonce = try AES.GCM.Nonce(data: ivData)
            let plaintext = try Self.serializeNode(node, codec: Self.defaultCodec)
            data = try EncryptionHelper.encrypt(data: plaintext, key: key, nonce: nonce)
        } else {
            guard let nodeData = node.toData() else { throw DataErrors.serializationFailed }
            data = nodeData
        }

        return data
    }

    func verifiedSerializedDataForStorage(keyProvider: (any KeyProvider)?) throws -> Data {
        let data = try serializedDataForStorage(keyProvider: keyProvider)
        try verifyData(data, matches: rawCID)
        return data
    }

    func collectVolumeEntries(
        into entries: inout [String: Data],
        visited: inout Set<String>,
        keyProvider: (any KeyProvider)?
    ) throws {
        guard !(self is any Volume) else { return }
        guard visited.insert(rawCID).inserted else { return }
        guard let node else { throw DataErrors.nodeNotAvailable }
        entries[rawCID] = try verifiedSerializedDataForStorage(keyProvider: keyProvider)
        try node.collectVolumeEntries(
            into: &entries,
            visited: &visited,
            keyProvider: keyProvider
        )
    }

    func storeSelectedVolumes(
        paths: ArrayTrie<StorageStrategy>,
        storer: any VolumeStorer
    ) async throws {
        if let volume = self as? any Volume {
            try await volume.store(paths: paths, storer: storer)
            return
        }

        guard let node else { throw DataErrors.nodeNotAvailable }
        if paths.isRecursiveHere {
            try await node.storeVolumesRecursively(storer: storer)
        } else {
            try await node.storeVolumes(paths: paths, storer: storer)
        }
    }

    func storeNestedVolumesRecursively(storer: any VolumeStorer) async throws {
        if let volume = self as? any Volume {
            try await volume.storeRecursively(storer: storer)
            return
        }

        guard let node else { throw DataErrors.nodeNotAvailable }
        try await node.storeVolumesRecursively(storer: storer)
    }
}
