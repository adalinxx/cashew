import Foundation
import Multicodec
import Crypto

/// A typed, content-addressed **reference** to a ``Node`` that is *not* part of
/// the referrer's owned closure.
///
/// Unlike ``Header``/``Volume``, a `Reference` is **not** a child node. It does
/// not conform to ``Header``, so it can never be returned from
/// `Node.get(property:)` nor appear in `Node.properties()`. The generic
/// store/resolve/proof walkers only descend into child *headers*, so a
/// `Reference` is **structurally** a leaf — there is no override to remember and
/// no way to accidentally recurse into it. It commits a CID in the referrer's
/// serialized bytes and nothing more; the referenced object is owned, stored,
/// and retained independently (by whoever owns it). A referrer never stores it,
/// and a recursive walk never pulls it.
///
/// This is the type-level expression of "owned child vs committed reference":
/// model a field as a ``Volume``/``Header`` when the object owns it (it belongs
/// in the object's stored closure and reachability), and as a `Reference` when
/// the field merely points at an independently-retained object (e.g. a backward
/// or shared link).
///
/// Resolve the referenced object explicitly by CID via ``resolve(fetcher:)`` /
/// ``resolve(source:)``.
///
/// **Wire shape:** a `Reference` encodes identically to an unhydrated
/// ``VolumeImpl``/``HeaderImpl`` (a `{rawCID, encryptionInfo?}` map), so flipping
/// an owned `Volume`/`Header` field to a `Reference` leaves the referrer's bytes
/// — and therefore its CID — unchanged.
public struct Reference<NodeType: Node>: Codable, Sendable {
    /// The content identifier of the referenced object.
    public let rawCID: String

    /// Encryption metadata for the referenced object, or nil if plaintext.
    public let encryptionInfo: EncryptionInfo?

    public init(rawCID: String, encryptionInfo: EncryptionInfo? = nil) {
        self.rawCID = rawCID
        self.encryptionInfo = encryptionInfo
    }

    /// Reference an existing header's target, reusing its CID and encryption
    /// info. The common construction: the referrer holds (or just built) the
    /// object as a header and commits a reference to it.
    public init<H: Header>(_ header: H) where H.NodeType == NodeType {
        self.rawCID = header.rawCID
        self.encryptionInfo = header.encryptionInfo
    }

    /// Build a plaintext reference to an object in hand, committing its CID.
    public init(to node: NodeType, codec: Codecs = .dag_cbor) throws {
        self.rawCID = try HeaderImpl<NodeType>.createSyncCID(for: node, codec: codec)
        self.encryptionInfo = nil
    }

    // MARK: - Resolve the referenced object by CID (single level)

    /// Fetch and decode the referenced object. Verifies the fetched bytes
    /// against `rawCID` and decrypts if `encryptionInfo` is present — the same
    /// path a ``Header`` uses, via a transient header (a `Reference` reuses the
    /// machinery without being a child node itself).
    public func resolve(fetcher: Fetcher) async throws -> NodeType {
        try await HeaderImpl<NodeType>(rawCID: rawCID, node: nil, encryptionInfo: encryptionInfo)
            .fetchAndDecodeNode(fetcher: fetcher)
    }

    /// Resolve the referenced object against a batched ``ContentSource``.
    public func resolve(source: any ContentSource) async throws -> NodeType {
        try await resolve(fetcher: CoalescingFetcher(source))
    }

    // MARK: - Codable (wire-identical to an unhydrated VolumeImpl/HeaderImpl)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawCID, forKey: .rawCID)
        try container.encodeIfPresent(encryptionInfo, forKey: .encryptionInfo)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawCID = try container.decode(String.self, forKey: .rawCID)
        encryptionInfo = try container.decodeIfPresent(EncryptionInfo.self, forKey: .encryptionInfo)
    }

    private enum CodingKeys: String, CodingKey {
        case rawCID
        case encryptionInfo
    }
}
