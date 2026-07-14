import Foundation
import Crypto

/// One complete Volume boundary ready for persistence.
///
/// `entries` contains the root and every ordinary Header reachable before the
/// next nested Volume boundary. Cashew materializes the complete dictionary
/// before calling the storer, so temporary memory scales with boundary size.
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

actor VolumeStorageSession: VolumeStorer, KeyProvider {
    nonisolated private let storer: any VolumeStorer
    private var storedRoots = Set<String>()
    private var recursivelyExpandedRoots = Set<String>()

    init(storer: any VolumeStorer) {
        self.storer = storer
    }

    func claim(root: String) -> Bool {
        storedRoots.insert(root).inserted
    }

    func cancel(root: String) {
        storedRoots.remove(root)
    }

    func storeClaimed(volume: SerializedVolume) async throws {
        try await storer.store(volume: volume)
    }

    func claimRecursiveExpansion(root: String) -> Bool {
        recursivelyExpandedRoots.insert(root).inserted
    }

    func store(volume: SerializedVolume) async throws {
        guard storedRoots.insert(volume.root).inserted else { return }
        do {
            try await storer.store(volume: volume)
        } catch {
            storedRoots.remove(volume.root)
            throw error
        }
    }

    nonisolated func key(for keyHash: String) -> SymmetricKey? {
        (storer as? any KeyProvider)?.key(for: keyHash)
    }
}

func volumeStorageSession(_ storer: any VolumeStorer) -> VolumeStorageSession {
    storer as? VolumeStorageSession ?? VolumeStorageSession(storer: storer)
}
