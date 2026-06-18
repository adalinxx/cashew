import Testing
import Foundation
import Crypto
@testable import cashew

/// Tests for ``Reference`` — a typed content-addressed reference that is *not* a
/// child node, and is therefore a structural leaf for store/resolve.
@Suite("Reference")
struct ReferenceTests {

    /// A node with one OWNED child (a header, in `properties()`) and one
    /// REFERENCE (a plain field, not in `properties()`). This is the block-shaped
    /// distinction: owned children are walked/stored; references are not.
    struct RefParent: Node {
        let owned: HeaderImpl<TestScalar>
        let ref: Reference<TestScalar>

        func get(property: PathSegment) -> (any Header)? {
            property == "owned" ? owned : nil   // `ref` is deliberately NOT exposed
        }
        func properties() -> Set<PathSegment> { ["owned"] }
        func set(properties: [PathSegment: any Header]) -> RefParent {
            RefParent(owned: properties["owned"] as? HeaderImpl<TestScalar> ?? owned, ref: ref)
        }
    }

    // MARK: - Wire compatibility

    /// A `Reference<T>` encodes byte-identically to an unhydrated `VolumeImpl<T>`
    /// / `HeaderImpl<T>` with the same CID — so flipping an owned field to a
    /// reference leaves the referrer's bytes (and its CID) unchanged.
    @Test func encodesIdenticallyToUnhydratedVolumeAndHeader() throws {
        let cid = try HeaderImpl(node: TestScalar(val: 7)).rawCID

        let refBytes = try DagCBOR.encode(Reference<TestScalar>(rawCID: cid))
        let volBytes = try DagCBOR.encode(VolumeImpl<TestScalar>(rawCID: cid, node: nil, encryptionInfo: nil))
        let hdrBytes = try DagCBOR.encode(HeaderImpl<TestScalar>(rawCID: cid, node: nil, encryptionInfo: nil))

        #expect(refBytes == volBytes)
        #expect(refBytes == hdrBytes)
    }

    /// Encryption metadata round-trips and stays wire-identical to a Volume.
    @Test func encodesIdenticallyWithEncryptionInfo() throws {
        let cid = try HeaderImpl(node: TestScalar(val: 7)).rawCID
        let info = EncryptionInfo(keyHash: "kh", iv: "iv")

        let refBytes = try DagCBOR.encode(Reference<TestScalar>(rawCID: cid, encryptionInfo: info))
        let volBytes = try DagCBOR.encode(VolumeImpl<TestScalar>(rawCID: cid, node: nil, encryptionInfo: info))
        #expect(refBytes == volBytes)

        let decoded = try DagCBOR.decode(Reference<TestScalar>.self, from: refBytes)
        #expect(decoded.rawCID == cid)
        #expect(decoded.encryptionInfo?.keyHash == "kh")
    }

    // MARK: - Construction

    /// `Reference(to:)` and `Reference(header)` commit the same CID the object is
    /// stored under as a Volume/Header.
    @Test func constructionCommitsTheObjectsCID() throws {
        let scalar = TestScalar(val: 42)
        let header = try HeaderImpl(node: scalar)
        let volume = try VolumeImpl(node: scalar)

        #expect(try Reference(to: scalar).rawCID == header.rawCID)
        #expect(Reference(header).rawCID == header.rawCID)
        #expect(Reference(volume).rawCID == header.rawCID)
    }

    // MARK: - Resolve by CID

    /// A reference resolves to the stored object via its CID (single level),
    /// reusing the header fetch/verify/decode path.
    @Test func resolvesReferencedObjectByCID() async throws {
        let scalar = TestScalar(val: 99)
        let header = try HeaderImpl(node: scalar)
        let store = TestStoreFetcher()
        try header.storeRecursively(storer: store)

        let ref = Reference<TestScalar>(rawCID: header.rawCID)
        let resolved = try await ref.resolve(fetcher: store)
        #expect(resolved.val == 99)

        // ...and over a batched ContentSource.
        let viaSource = try await ref.resolve(source: store)
        #expect(viaSource.val == 99)
    }

    /// Resolving a reference whose target was never stored fails (it is not
    /// magically present in the referrer's closure).
    @Test func resolvingAbsentReferenceThrows() async throws {
        let ref = try Reference(to: TestScalar(val: 123))
        let store = TestStoreFetcher()
        await #expect(throws: (any Error).self) {
            _ = try await ref.resolve(fetcher: store)
        }
    }

    // MARK: - The structural-leaf guarantee

    /// Storing a node recursively stores its OWNED child but NOT its reference's
    /// target — the reference is not a child, so the store walk never descends
    /// into it. This is the property the retention model depends on.
    @Test func storeRecursivelyDoesNotStoreReferenceTarget() async throws {
        let ownedScalar = TestScalar(val: 1)
        let referencedScalar = TestScalar(val: 2)
        let ownedHeader = try HeaderImpl(node: ownedScalar)
        let referencedCID = try HeaderImpl(node: referencedScalar).rawCID

        let parent = RefParent(owned: ownedHeader, ref: Reference(rawCID: referencedCID))
        let parentHeader = try HeaderImpl(node: parent)

        let store = TestStoreFetcher()
        try parentHeader.storeRecursively(storer: store)

        // The owned child IS stored and resolvable.
        _ = try await HeaderImpl<TestScalar>(rawCID: ownedHeader.rawCID).resolve(fetcher: store)
        // The referenced target is NOT stored — the parent never walked into it.
        await #expect(throws: (any Error).self) {
            _ = try await HeaderImpl<TestScalar>(rawCID: referencedCID).resolve(fetcher: store)
        }
    }

    /// Recursively resolving the referrer pulls its owned closure but leaves the
    /// reference untouched (a recursive walk does not climb through references).
    @Test func resolveRecursiveDoesNotPullReference() async throws {
        let ownedScalar = TestScalar(val: 5)
        let referencedScalar = TestScalar(val: 6)
        let parent = RefParent(
            owned: try HeaderImpl(node: ownedScalar),
            ref: try Reference(to: referencedScalar))
        let parentHeader = try HeaderImpl(node: parent)

        // Store ONLY the parent's owned closure (not the referenced object).
        let store = TestStoreFetcher()
        try parentHeader.storeRecursively(storer: store)

        // resolveRecursive succeeds without the referenced object being present,
        // proving the walk never tried to fetch it.
        let resolved = try await HeaderImpl<RefParent>(rawCID: parentHeader.rawCID)
            .resolveRecursive(fetcher: store)
        #expect(resolved.node?.owned.node?.val == 5)
        #expect(resolved.node?.ref.rawCID == parent.ref.rawCID)
    }
}
