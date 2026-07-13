import XCTest
@testable import cashew

final class VolumeStoreLifecycleTests: XCTestCase {
    private struct Leaf: Scalar, Equatable {
        let value: String
    }

    private enum InjectedFailure: Error {
        case store
    }

    private final class RecordingStorer: VolumeAwareStorer {
        var events: [String] = []
        var failOnStore = false

        func enterVolume(rootCID: String) throws {
            events.append("enter:\(rootCID)")
        }

        func exitVolume(rootCID: String) throws {
            events.append("exit:\(rootCID)")
        }

        func abortVolume(rootCID: String) {
            events.append("abort:\(rootCID)")
        }

        func store(rawCid: String, data: Data) throws {
            events.append("store:\(rawCid)")
            if failOnStore { throw InjectedFailure.store }
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
    }

    func testFailedTraversalAbortsInsteadOfPublishingPartialScope() throws {
        let volume = try VolumeImpl<Leaf>(node: Leaf(value: "incomplete"))
        let storer = RecordingStorer()
        storer.failOnStore = true

        XCTAssertThrowsError(try volume.storeRecursively(storer: storer)) { error in
            XCTAssertTrue(error is InjectedFailure)
        }

        XCTAssertEqual(storer.events, [
            "enter:\(volume.rawCID)",
            "store:\(volume.rawCID)",
            "abort:\(volume.rawCID)",
        ])
        XCTAssertFalse(storer.events.contains("exit:\(volume.rawCID)"))
    }
}
