import Foundation
import Multicodec
import Multihash
import CID
import Crypto

/// A point in a Merkle DAG where peers may store child blocks contiguously.
///
/// A Volume marks a semantically important boundary in the data structure.
/// When resolution enters a Volume, the fetcher is notified with the CID of
/// this point and the resolution paths, so it can locate a peer that holds
/// the child blocks under this CID.
///
/// Volumes can be nested. Each Volume boundary triggers its own ``provide``
/// call on the fetcher, allowing it to locate different peers for each volume.
///
/// ```swift
/// typealias UserVolume = VolumeImpl<MerkleDictionaryImpl<String>>
/// let vol = UserVolume(node: users)
/// let resolved = try await vol.resolve(paths: paths, fetcher: fetcher)
/// ```
public protocol Volume: Header { }

/// Default concrete implementation of ``Volume``.
public struct VolumeImpl<NodeType: Node>: Volume {
    public let rawCID: String
    public let rawNode: Box<NodeType>?
    public let encryptionInfo: EncryptionInfo?

    public var node: NodeType? {
        return rawNode?.boxed
    }

    public init(rawCID: String, node: NodeType?, encryptionInfo: EncryptionInfo?) {
        self.rawCID = rawCID
        self.rawNode = node.map { Box($0) }
        self.encryptionInfo = encryptionInfo
    }

    public init(node: NodeType, key: SymmetricKey) throws {
        let plaintext = try Self.serializeNode(node, codec: Self.defaultCodec)
        let (encrypted, iv) = try EncryptionHelper.encrypt(data: plaintext, key: key)
        let multihash = try Multihash(raw: encrypted, hashedWith: .sha2_256)
        let cid = try CID(version: .v1, codec: Self.defaultCodec, multihash: multihash)
        self.rawCID = cid.toBaseEncodedString
        self.rawNode = Box(node)
        self.encryptionInfo = EncryptionInfo(key: key, iv: iv)
    }
}

// MARK: - Codable
extension VolumeImpl: Codable where NodeType: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawCID, forKey: .rawCID)
        try container.encodeIfPresent(encryptionInfo, forKey: .encryptionInfo)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawCID = try container.decode(String.self, forKey: .rawCID)
        encryptionInfo = try container.decodeIfPresent(EncryptionInfo.self, forKey: .encryptionInfo)
        rawNode = nil
    }

    private enum CodingKeys: String, CodingKey {
        case rawCID
        case encryptionInfo
    }
}
