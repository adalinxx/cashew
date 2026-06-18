import Testing
import Foundation
import ArrayTrie
@testable import cashew

@Suite("DagCBOR Regression Tests")
struct DagCBORRegressionTests {
    struct UInt64Record: Codable, Equatable {
        let max: UInt64
        let highBit: UInt64
        let aboveJSONSafeInteger: UInt64
    }

    struct DataRecord: Codable, Equatable {
        let payload: Data
    }

    @available(macOS 15, iOS 18, watchOS 11, tvOS 18, *)
    struct Wide128Record: Codable, Equatable {
        let u: UInt128
        let i: Int128
    }

    struct KeyOrderRecord: Codable {
        let bb: Int
        let a: Int
        let aa: Int
        let b: Int
    }

    struct FailingNode: Node {
        init() {}

        func encode(to encoder: Encoder) throws {
            throw DagCBORError.unsupportedType
        }

        init(from decoder: Decoder) throws {
            throw DagCBORError.invalidCBOR
        }

        func get(property: PathSegment) -> (any Header)? { nil }
        func properties() -> Set<PathSegment> { [] }
        func set(properties: [PathSegment: any Header]) -> Self { self }
    }

    final class RecordingFetcher: Fetcher, @unchecked Sendable {
        private let lock = NSLock()
        private let data: [String: Data]
        private var fetchedRawCIDs: Set<String> = []

        init(data: [String: Data]) {
            self.data = data
        }

        var fetchedCIDs: Set<String> {
            lock.withLock { fetchedRawCIDs }
        }

        func fetch(rawCid: String) async throws -> Data {
            _ = lock.withLock { fetchedRawCIDs.insert(rawCid) }
            guard let value = data[rawCid] else { throw FetchError.notFound }
            return value
        }
    }

    @Test("UInt64 values above Int64.max encode as major-0 and round-trip")
    func testFullUInt64RoundTrip() throws {
        let record = UInt64Record(
            max: UInt64.max,
            highBit: UInt64(1) << 63,
            aboveJSONSafeInteger: (UInt64(1) << 53) + 1
        )

        let encoded = try DagCBOR.encode(record)
        let decoded = try DagCBOR.decode(UInt64Record.self, from: encoded)
        #expect(decoded == record)

        #expect(try DagCBOR.encode(UInt64.max) == Data([0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]))
        #expect(try DagCBOR.encode(UInt64(1) << 63) == Data([0x1b, 0x80, 0, 0, 0, 0, 0, 0, 0]))
        #expect(try DagCBOR.encode((UInt64(1) << 53) + 1) == Data([0x1b, 0, 0x20, 0, 0, 0, 0, 0, 1]))
    }

    @available(macOS 15, iOS 18, watchOS 11, tvOS 18, *)
    @Test("UInt128/Int128 round-trip and small values stay byte-identical to 64-bit encoding")
    func testWide128RoundTrip() throws {
        // Small values (nonces) must encode exactly as the 64-bit encoders do
        // so existing CIDs are unchanged.
        #expect(try DagCBOR.encode(UInt128(0)) == DagCBOR.encode(UInt64(0)))
        #expect(try DagCBOR.encode(UInt128(1)) == Data([0x01]))
        #expect(try DagCBOR.encode(UInt128(1000)) == DagCBOR.encode(UInt64(1000)))
        #expect(try DagCBOR.encode(Int128(-50)) == DagCBOR.encode(Int64(-50)))
        // Full 64-bit boundary still representable.
        #expect(try DagCBOR.encode(UInt128(UInt64.max)) == Data([0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]))

        let record = Wide128Record(u: UInt128(UInt64.max), i: Int128(-123456789))
        let decoded = try DagCBOR.decode(Wide128Record.self, from: try DagCBOR.encode(record))
        #expect(decoded == record)

        // Beyond the 64-bit range is rejected fail-closed, never trapped/truncated.
        #expect(throws: DagCBORError.self) { _ = try DagCBOR.encode(UInt128(UInt64.max) + 1) }
        // value < -(2^64) overflows the 64-bit CBOR negative argument.
        #expect(throws: DagCBORError.self) { _ = try DagCBOR.encode(-Int128(UInt64.max) - 2) }
    }

    @Test("Data fields remain base64 CBOR text strings")
    func testDataEncodesAsBase64Text() throws {
        let record = DataRecord(payload: Data([1, 2, 3, 4]))
        let encoded = try DagCBOR.encode(record)
        let decoded = try DagCBOR.decode(DataRecord.self, from: encoded)

        #expect(decoded == record)
        #expect(encoded == Data([0xa1, 0x67, 0x70, 0x61, 0x79, 0x6c, 0x6f, 0x61, 0x64, 0x68, 0x41, 0x51, 0x49, 0x44, 0x42, 0x41, 0x3d, 0x3d]))
        let valueInitialByte = encoded[9]
        #expect(valueInitialByte >> 5 == 3)
        #expect(valueInitialByte >> 5 != 2)
    }

    @Test("Map keys serialize length-first then lexicographic")
    func testMapKeyOrderingUnchanged() throws {
        let encoded = try DagCBOR.encode(KeyOrderRecord(bb: 4, a: 1, aa: 3, b: 2))
        let expected = Data([
            0xa4,
            0x61, 0x61, 0x01,
            0x61, 0x62, 0x02,
            0x62, 0x61, 0x61, 0x03,
            0x62, 0x62, 0x62, 0x04
        ])
        #expect(encoded == expected)
    }

    @Test("Synchronous Header CID creation throws on serialization failure")
    func testHeaderInitThrowsOnSerializationFailure() {
        #expect(throws: DataErrors.self) {
            _ = try HeaderImpl(node: FailingNode())
        }
        #expect(throws: DataErrors.self) {
            _ = try HeaderImpl<FailingNode>.createSyncCID(for: FailingNode(), codec: .dag_cbor)
        }
    }

    @Test("Deleting a value-less exact prefix throws")
    func testDeletingValueLessPrefixThrows() throws {
        let child = try RadixHeaderImpl(node: RadixNodeImpl<String>(prefix: "d", value: "value", children: [:]))
        let valueLess = RadixNodeImpl<String>(prefix: "abc", value: nil, children: ["d": child])

        #expect(throws: TransformErrors.self) {
            _ = try valueLess.deleting(key: ArraySlice("abc"))
        }

        typealias Inner = MerkleDictionaryImpl<String>
        typealias InnerHeader = HeaderImpl<Inner>
        let headerChild = try RadixHeaderImpl(
            node: RadixNodeImpl<InnerHeader>(prefix: "z", value: try InnerHeader(node: Inner()), children: [:])
        )
        let specializedValueLess = RadixNodeImpl<InnerHeader>(prefix: "abc", value: nil, children: ["z": headerChild])
        var transforms = ArrayTrie<Transform>()
        transforms.set(["abc"], value: .delete)

        #expect(throws: TransformErrors.self) {
            _ = try specializedValueLess.transform(transforms: transforms, keyProvider: nil)
        }
    }

    @Test("Batched deletion expansion only fetches collapse-possible grandchildren")
    func testBatchedDeletionExpansionSpy() async throws {
        let collapse = try Self.makeProofSpyNode()
        var collapsePaths = ArrayTrie<SparseMerkleProof>()
        collapsePaths.set(["ra"], value: .deletion)
        collapsePaths.set(["rb"], value: .deletion)

        #expect(collapse.node.shouldExpandForBatchedDeletion(paths: collapsePaths.traverse(path: "r")!))
        _ = try await collapse.node.proof(paths: collapsePaths, fetcher: collapse.fetcher)
        #expect(collapse.fetcher.fetchedCIDs == Set(collapse.cids.values))

        let twoSurvivors = try Self.makeProofSpyNode()
        var twoSurvivorPaths = ArrayTrie<SparseMerkleProof>()
        twoSurvivorPaths.set(["ra"], value: .deletion)
        twoSurvivorPaths.set(["rb"], value: .existence)

        #expect(!twoSurvivors.node.shouldExpandForBatchedDeletion(paths: twoSurvivorPaths.traverse(path: "r")!))
        _ = try await twoSurvivors.node.proof(paths: twoSurvivorPaths, fetcher: twoSurvivors.fetcher)
        #expect(!twoSurvivors.fetcher.fetchedCIDs.contains(twoSurvivors.cids["c"]!))
    }

    private static func makeProofSpyNode() throws -> (
        node: RadixNodeImpl<String>,
        fetcher: RecordingFetcher,
        cids: [Character: String]
    ) {
        var storage: [String: Data] = [:]
        var cids: [Character: String] = [:]
        var children: [Character: RadixHeaderImpl<String>] = [:]

        for key in Array("abc") {
            let childNode = RadixNodeImpl<String>(prefix: String(key), value: String(key), children: [:])
            let loadedHeader = try RadixHeaderImpl(node: childNode)
            guard let data = childNode.toData() else { throw DataErrors.serializationFailed }
            storage[loadedHeader.rawCID] = data
            cids[key] = loadedHeader.rawCID
            children[key] = RadixHeaderImpl(rawCID: loadedHeader.rawCID)
        }

        return (
            RadixNodeImpl<String>(prefix: "r", value: nil, children: children),
            RecordingFetcher(data: storage),
            cids
        )
    }
}
