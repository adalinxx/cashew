import Foundation

/// Persists an arbitrary set of verified content-addressed blocks.
///
/// Unlike ``VolumeStorer``, this port makes no completeness or retention
/// guarantee. It is suitable for sparse DAGs, replication, and read-through
/// caches. Repeated writes of the same CID and bytes must be idempotent.
public protocol Storer: Sendable {
    func store(entries: [String: Data]) async throws
}
