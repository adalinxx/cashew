import Foundation

/// One complete Volume boundary ready for persistence.
///
/// `entries` contains the root and every ordinary Header reachable before the
/// next nested Volume boundary.
public struct SerializedVolume: Sendable {
    public let root: String
    public let entries: [String: Data]

    public init(root: String, entries: [String: Data]) {
        self.root = root
        self.entries = entries
    }
}

/// Persists complete Volume boundaries emitted by Cashew's storage planner.
///
/// Cashew calls this once per selected Volume, after the full boundary has been
/// serialized. A conformer never has to track enter/exit/abort state.
public protocol VolumeStorer: Sendable {
    func store(volume: SerializedVolume) async throws
}
