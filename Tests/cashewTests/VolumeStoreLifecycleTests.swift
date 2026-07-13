import Crypto
import Foundation
import XCTest
@testable import cashew

final class VolumeStoreLifecycleTests: XCTestCase {
    private struct Leaf: Scalar, Equatable {
        let value: String
    }

    private struct OwnedChildNode: Node, Sendable {
        let child: HeaderImpl<Leaf>

        func get(property: PathSegment) -> (any Header)? {
            property == "child" ? child : nil
        }

        func properties() -> Set<PathSegment> { ["child"] }

        func set(properties: [PathSegment: any Header]) -> Self {
            guard let replacement = properties["child"] as? HeaderImpl<Leaf> else { return self }
            return Self(child: replacement)
        }
    }

    private struct NestedVolumeNode: Node, Sendable {
        let child: VolumeImpl<Leaf>

        func get(property: PathSegment) -> (any Header)? {
            property == "child" ? child : nil
        }

        func properties() -> Set<PathSegment> { ["child"] }

        func set(properties: [PathSegment: any Header]) -> Self {
            guard let replacement = properties["child"] as? VolumeImpl<Leaf> else { return self }
            return Self(child: replacement)
        }
    }

    private struct MissingDeclaredChildNode: Node, Sendable {
        func get(property: PathSegment) -> (any Header)? { nil }
        func properties() -> Set<PathSegment> { ["missing"] }
        func set(properties: [PathSegment: any Header]) -> Self { self }
    }

    private enum EncodingFailure: Error {
        case injected
    }

    private struct FailingLeaf: Scalar {
        init() {}

        init(from decoder: Decoder) throws {
            self.init()
        }

        func encode(to encoder: Encoder) throws {
            throw EncodingFailure.injected
        }
    }

    private struct FailingChildNode: Node, Sendable {
        let child: HeaderImpl<FailingLeaf>

        func get(property: PathSegment) -> (any Header)? {
            property == "child" ? child : nil
        }

        func properties() -> Set<PathSegment> { ["child"] }

        func set(properties: [PathSegment: any Header]) -> Self {
            guard let replacement = properties["child"] as? HeaderImpl<FailingLeaf> else { return self }
            return Self(child: replacement)
        }
    }

    private enum InjectedFailure: Error, Equatable {
        case enter(String)
        case store(String)
        case exit(String)
        case mismatchedExit(expected: String?, actual: String)
    }

    private final class RecordingStorer: VolumeAwareStorer, Fetcher, KeyProvider, @unchecked Sendable {
        var events: [String] = []
        var contained = Set<String>()
        var failOnEnterCID: String?
        var failOnStoreCID: String?
        var failOnExitCID: String?
        var keys: [String: SymmetricKey] = [:]

        private(set) var stack: [String] = []
        private(set) var abortCounts: [String: Int] = [:]
        private(set) var completedRoots: [String] = []
        private(set) var storedData: [String: Data] = [:]

        func enterVolume(rootCID: String) throws {
            stack.append(rootCID)
            events.append("enter:\(rootCID)")
            if failOnEnterCID == rootCID {
                throw InjectedFailure.enter(rootCID)
            }
        }

        func exitVolume(rootCID: String) throws {
            let expected = stack.last
            guard expected == rootCID else {
                throw InjectedFailure.mismatchedExit(expected: expected, actual: rootCID)
            }
            events.append("exit:\(rootCID)")
            if failOnExitCID == rootCID {
                throw InjectedFailure.exit(rootCID)
            }
            stack.removeLast()
            completedRoots.append(rootCID)
        }

        func abortVolume(rootCID: String) {
            events.append("abort:\(rootCID)")
            abortCounts[rootCID, default: 0] += 1
            guard let index = stack.lastIndex(of: rootCID) else { return }
            stack.removeSubrange(index...)
        }

        func store(rawCid: String, data: Data) throws {
            events.append("store:\(rawCid)")
            if failOnStoreCID == rawCid {
                throw InjectedFailure.store(rawCid)
            }
            storedData[rawCid] = data
        }

        func contains(rawCid: String) -> Bool {
            contained.contains(rawCid)
        }

        func key(for keyHash: String) -> SymmetricKey? {
            keys[keyHash]
        }

        func fetch(rawCid: String) async throws -> Data {
            guard let data = storedData[rawCid] else { throw FetchError.notFound }
            return data
        }
    }

    private final class PlainRecordingStorer: Storer {
        var contained = Set<String>()
        private(set) var stored: [String] = []

        func store(rawCid: String, data: Data) throws {
            stored.append(rawCid)
        }

        func contains(rawCid: String) -> Bool {
            contained.contains(rawCid)
        }
    }

    func testSuccessfulTraversalPublishesExactlyOneCompleteScope() throws {
        let volume = try VolumeImpl<Leaf>(node: Leaf(value: "complete"))
        let storer = RecordingStorer()

        try volume.storeRecursively(storer: storer)

        XCTAssertEqual(storer.events, [
            "enter:\(volume.rawCID)",
            "store:\(volume.rawCID)",
            "exit:\(volume.rawCID)",
        ])
        XCTAssertEqual(storer.completedRoots, [volume.rawCID])
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testFailedTraversalAbortsInsteadOfPublishingPartialScope() throws {
        let volume = try VolumeImpl<Leaf>(node: Leaf(value: "incomplete"))
        let storer = RecordingStorer()
        storer.failOnStoreCID = volume.rawCID

        XCTAssertThrowsError(try volume.storeRecursively(storer: storer)) { error in
            XCTAssertEqual(error as? InjectedFailure, .store(volume.rawCID))
        }

        XCTAssertEqual(storer.events, [
            "enter:\(volume.rawCID)",
            "store:\(volume.rawCID)",
            "abort:\(volume.rawCID)",
        ])
        XCTAssertTrue(storer.completedRoots.isEmpty)
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testEnterFailureCleansPartiallyOpenedScope() throws {
        let volume = try VolumeImpl<Leaf>(node: Leaf(value: "entry"))
        let storer = RecordingStorer()
        storer.failOnEnterCID = volume.rawCID

        XCTAssertThrowsError(try volume.storeRecursively(storer: storer)) { error in
            XCTAssertEqual(error as? InjectedFailure, .enter(volume.rawCID))
        }

        XCTAssertEqual(storer.events, [
            "enter:\(volume.rawCID)",
            "abort:\(volume.rawCID)",
        ])
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testUnresolvedRootVolumeFailsBeforeOpeningScope() throws {
        let resolved = try VolumeImpl<Leaf>(node: Leaf(value: "root"))
        let unresolved = VolumeImpl<Leaf>(rawCID: resolved.rawCID)
        let storer = RecordingStorer()

        XCTAssertThrowsError(try unresolved.storeRecursively(storer: storer)) { error in
            guard let dataError = error as? DataErrors,
                  case .nodeNotAvailable = dataError else {
                return XCTFail("expected nodeNotAvailable, got \(error)")
            }
        }
        XCTAssertTrue(storer.events.isEmpty)
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testUnresolvedVolumeRadixHeaderUsesVolumeLifecycle() throws {
        let node = VolumeRadixNodeImpl<String>(prefix: "root", value: "value", children: [:])
        let resolved = try VolumeRadixHeaderImpl<String>(node: node)
        let unresolved = VolumeRadixHeaderImpl<String>(rawCID: resolved.rawCID)
        let storer = RecordingStorer()

        XCTAssertThrowsError(try unresolved.storeRecursively(storer: storer)) { error in
            XCTAssertEqual(error as? DataErrors, .nodeNotAvailable)
        }
        XCTAssertTrue(storer.events.isEmpty)
    }

    func testUnresolvedSameBoundaryChildAbortsOuterVolume() throws {
        let child = try HeaderImpl<Leaf>(node: Leaf(value: "owned"))
        let unresolvedChild = HeaderImpl<Leaf>(rawCID: child.rawCID)
        let outer = try VolumeImpl<OwnedChildNode>(node: OwnedChildNode(child: unresolvedChild))
        let storer = RecordingStorer()

        XCTAssertThrowsError(try outer.storeRecursively(storer: storer)) { error in
            guard let dataError = error as? DataErrors,
                  case .nodeNotAvailable = dataError else {
                return XCTFail("expected nodeNotAvailable, got \(error)")
            }
        }

        XCTAssertEqual(storer.events, [
            "enter:\(outer.rawCID)",
            "store:\(outer.rawCID)",
            "abort:\(outer.rawCID)",
        ])
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testMissingDeclaredChildAbortsOuterVolume() throws {
        let outer = try VolumeImpl<MissingDeclaredChildNode>(node: MissingDeclaredChildNode())
        let storer = RecordingStorer()

        XCTAssertThrowsError(try outer.storeRecursively(storer: storer)) { error in
            guard let dataError = error as? DataErrors else {
                return XCTFail("expected DataErrors, got \(error)")
            }
            guard case .missingDeclaredChild(let property) = dataError else {
                return XCTFail("expected missingDeclaredChild, got \(error)")
            }
            XCTAssertEqual(property, "missing")
        }

        XCTAssertEqual(storer.events.last, "abort:\(outer.rawCID)")
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testUnresolvedNestedVolumeCompletesOuterWithoutStoringChild() throws {
        let resolvedChild = try VolumeImpl<Leaf>(node: Leaf(value: "independent"))
        let unresolvedChild = VolumeImpl<Leaf>(rawCID: resolvedChild.rawCID)
        let outer = try VolumeImpl<NestedVolumeNode>(node: NestedVolumeNode(child: unresolvedChild))
        let storer = RecordingStorer()

        try outer.storeRecursively(storer: storer)

        XCTAssertEqual(storer.events, [
            "enter:\(outer.rawCID)",
            "store:\(outer.rawCID)",
            "exit:\(outer.rawCID)",
        ])
        XCTAssertEqual(storer.completedRoots, [outer.rawCID])
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testNestedVolumeStorageIsIndependentOfParentCompletion() throws {
        let child = try VolumeImpl<Leaf>(node: Leaf(value: "nested"))
        let hydratedOuter = try VolumeImpl<NestedVolumeNode>(node: NestedVolumeNode(child: child))
        let unresolvedChild = VolumeImpl<Leaf>(rawCID: child.rawCID)
        let unhydratedOuter = try VolumeImpl<NestedVolumeNode>(node: NestedVolumeNode(child: unresolvedChild))

        XCTAssertEqual(hydratedOuter.rawCID, unhydratedOuter.rawCID)

        let hydratedStore = RecordingStorer()
        let unhydratedStore = RecordingStorer()
        try hydratedOuter.storeRecursively(storer: hydratedStore)
        try unhydratedOuter.storeRecursively(storer: unhydratedStore)

        XCTAssertEqual(Array(hydratedStore.events.prefix(3)), [
            "enter:\(hydratedOuter.rawCID)",
            "store:\(hydratedOuter.rawCID)",
            "exit:\(hydratedOuter.rawCID)",
        ])
        XCTAssertEqual(unhydratedStore.events, Array(hydratedStore.events.prefix(3)))
        XCTAssertTrue(hydratedStore.completedRoots.contains(child.rawCID))
        XCTAssertFalse(unhydratedStore.completedRoots.contains(child.rawCID))
    }

    func testNestedChildFailureDoesNotUnpublishCompletedOuterVolume() throws {
        let child = try VolumeImpl<Leaf>(node: Leaf(value: "child"))
        let outer = try VolumeImpl<NestedVolumeNode>(node: NestedVolumeNode(child: child))
        let storer = RecordingStorer()
        storer.failOnStoreCID = child.rawCID

        XCTAssertThrowsError(try outer.storeRecursively(storer: storer)) { error in
            XCTAssertEqual(error as? InjectedFailure, .store(child.rawCID))
        }

        XCTAssertEqual(storer.events, [
            "enter:\(outer.rawCID)",
            "store:\(outer.rawCID)",
            "exit:\(outer.rawCID)",
            "enter:\(child.rawCID)",
            "store:\(child.rawCID)",
            "abort:\(child.rawCID)",
        ])
        XCTAssertTrue(storer.completedRoots.contains(outer.rawCID))
        XCTAssertFalse(storer.completedRoots.contains(child.rawCID))
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testDirectOrdinaryHeaderKeepsBestEffortSemanticsWithVolumeAwareStorer() throws {
        let materialized = try HeaderImpl<Leaf>(node: Leaf(value: "ordinary"))
        let unresolved = HeaderImpl<Leaf>(rawCID: materialized.rawCID)
        let storer = RecordingStorer()
        storer.contained.insert(materialized.rawCID)

        XCTAssertNoThrow(try unresolved.storeRecursively(storer: storer))
        XCTAssertNoThrow(try materialized.storeRecursively(storer: storer))
        XCTAssertTrue(storer.events.isEmpty)
    }

    func testOuterExitFailureDoesNotStartNestedChild() throws {
        let child = try VolumeImpl<Leaf>(node: Leaf(value: "child"))
        let outer = try VolumeImpl<NestedVolumeNode>(node: NestedVolumeNode(child: child))
        let storer = RecordingStorer()
        storer.failOnExitCID = outer.rawCID

        XCTAssertThrowsError(try outer.storeRecursively(storer: storer)) { error in
            XCTAssertEqual(error as? InjectedFailure, .exit(outer.rawCID))
        }

        XCTAssertFalse(storer.events.contains("enter:\(child.rawCID)"))
        XCTAssertFalse(storer.completedRoots.contains(outer.rawCID))
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testVolumeAwareTraversalRecordsMembershipDespiteContains() throws {
        let child = try HeaderImpl<Leaf>(node: Leaf(value: "shared"))
        let outer = try VolumeImpl<OwnedChildNode>(node: OwnedChildNode(child: child))
        let storer = RecordingStorer()
        storer.contained.insert(child.rawCID)

        try outer.storeRecursively(storer: storer)

        XCTAssertTrue(
            storer.events.contains("store:\(child.rawCID)"),
            "existing content must still be recorded as a member of the current Volume"
        )
    }

    func testHeaderValuedRadixEntryIsStoredWithinVolume() throws {
        let child = try HeaderImpl<Leaf>(node: Leaf(value: "owned"))
        let dictionary = try MerkleDictionaryImpl<HeaderImpl<Leaf>>()
            .inserting(key: "child", value: child)
        let outer = try VolumeImpl(node: dictionary)
        let storer = RecordingStorer()

        try outer.storeRecursively(storer: storer)

        XCTAssertTrue(storer.events.contains("store:\(child.rawCID)"))
        XCTAssertEqual(storer.completedRoots, [outer.rawCID])
    }

    func testUnresolvedHeaderValuedRadixEntryAbortsVolume() throws {
        let resolved = try HeaderImpl<Leaf>(node: Leaf(value: "owned"))
        let unresolved = HeaderImpl<Leaf>(rawCID: resolved.rawCID)
        let dictionary = try MerkleDictionaryImpl<HeaderImpl<Leaf>>()
            .inserting(key: "child", value: unresolved)
        let outer = try VolumeImpl(node: dictionary)
        let storer = RecordingStorer()

        XCTAssertThrowsError(try outer.storeRecursively(storer: storer)) { error in
            XCTAssertEqual(error as? DataErrors, .nodeNotAvailable)
        }
        XCTAssertEqual(storer.events.last, "abort:\(outer.rawCID)")
        XCTAssertTrue(storer.completedRoots.isEmpty)
    }

    func testPlainStorerRetainsContentDeduplicationFastPath() throws {
        let header = try HeaderImpl<Leaf>(node: Leaf(value: "shared"))
        let storer = PlainRecordingStorer()
        storer.contained.insert(header.rawCID)

        try header.storeRecursively(storer: storer)

        XCTAssertTrue(storer.stored.isEmpty)
    }

    func testPlainStorerRetainsVolumeRadixHeaderDeduplicationFastPath() throws {
        let node = VolumeRadixNodeImpl<String>(prefix: "root", value: "value", children: [:])
        let header = try VolumeRadixHeaderImpl<String>(node: node)
        let storer = PlainRecordingStorer()
        storer.contained.insert(header.rawCID)

        try header.storeRecursively(storer: storer)

        XCTAssertTrue(storer.stored.isEmpty)
    }

    func testEncryptedVolumeRootStoresCiphertextMatchingItsCID() async throws {
        let key = SymmetricKey(size: .bits256)
        let volume = try VolumeImpl<Leaf>(node: Leaf(value: "encrypted"), key: key)
        let info = try XCTUnwrap(volume.encryptionInfo)
        let storer = RecordingStorer()
        storer.keys[info.keyHash] = key

        try volume.storeRecursively(storer: storer)

        let stored = try XCTUnwrap(storer.storedData[volume.rawCID])
        XCTAssertNotEqual(stored, volume.node?.toData())
        let decoded = try await volume.fetchAndDecodeNode(fetcher: storer)
        XCTAssertEqual(decoded, Leaf(value: "encrypted"))
    }

    func testDescendantEncryptionFailureAbortsOuterVolume() throws {
        let child = try HeaderImpl<Leaf>(node: Leaf(value: "secret"))
        let encryptedChild = HeaderImpl<Leaf>(
            rawCID: child.rawCID,
            node: child.node,
            encryptionInfo: EncryptionInfo(
                keyHash: "missing-key",
                iv: Data(repeating: 0, count: 12).base64EncodedString()
            )
        )
        let outer = try VolumeImpl<OwnedChildNode>(node: OwnedChildNode(child: encryptedChild))
        let storer = RecordingStorer()

        XCTAssertThrowsError(try outer.storeRecursively(storer: storer)) { error in
            guard let dataError = error as? DataErrors,
                  case .keyNotFound = dataError else {
                return XCTFail("expected keyNotFound, got \(error)")
            }
        }

        XCTAssertEqual(storer.events.last, "abort:\(outer.rawCID)")
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testDescendantSerializationFailureAbortsOuterVolume() throws {
        let placeholder = try HeaderImpl<Leaf>(node: Leaf(value: "placeholder"))
        let failingChild = HeaderImpl<FailingLeaf>(
            rawCID: placeholder.rawCID,
            node: FailingLeaf(),
            encryptionInfo: nil
        )
        let outer = try VolumeImpl<FailingChildNode>(node: FailingChildNode(child: failingChild))
        let storer = RecordingStorer()

        XCTAssertThrowsError(try outer.storeRecursively(storer: storer)) { error in
            guard let dataError = error as? DataErrors,
                  case .serializationFailed = dataError else {
                return XCTFail("expected serializationFailed, got \(error)")
            }
        }

        XCTAssertEqual(storer.events.last, "abort:\(outer.rawCID)")
        XCTAssertTrue(storer.stack.isEmpty)
    }

    func testMismatchedExitFailsAndAbortCleanupIsIdempotent() throws {
        let storer = RecordingStorer()
        try storer.enterVolume(rootCID: "outer")

        XCTAssertThrowsError(try storer.exitVolume(rootCID: "other")) { error in
            XCTAssertEqual(
                error as? InjectedFailure,
                .mismatchedExit(expected: "outer", actual: "other")
            )
        }
        XCTAssertEqual(storer.stack, ["outer"])

        storer.abortVolume(rootCID: "outer")
        storer.abortVolume(rootCID: "outer")

        XCTAssertTrue(storer.stack.isEmpty)
        XCTAssertEqual(storer.abortCounts["outer"], 2)
    }
}
