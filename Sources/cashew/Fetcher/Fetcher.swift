import CID
import Foundation

/// Retrieves serialized node data from a content-addressed store by CID.
public protocol Fetcher: Sendable {
    func fetch(rawCid: String) async throws -> Data
}
