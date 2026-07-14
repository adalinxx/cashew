import ArrayTrie

extension Volume {
    func storeCurrentVolume(storer: any VolumeStorer) async throws -> NodeType {
        guard let node else { throw DataErrors.nodeNotAvailable }

        let keyProvider = storer as? any KeyProvider
        var entries = [rawCID: try serializedDataForStorage(keyProvider: keyProvider)]
        var visited = Set([rawCID])
        try node.collectVolumeEntries(
            into: &entries,
            visited: &visited,
            keyProvider: keyProvider
        )

        try await storer.store(volume: SerializedVolume(root: rawCID, entries: entries))
        return node
    }
}

public extension Volume {
    /// Store this Volume and only the nested Volumes selected by `paths`.
    ///
    /// Paths use the same structural and compressed-radix traversal rules as
    /// resolution paths. The root Volume is always selected.
    func store(
        paths: [[String]: StorageStrategy],
        storer: any VolumeStorer
    ) async throws {
        var pathTrie = ArrayTrie<StorageStrategy>()
        for (path, strategy) in paths {
            pathTrie.set(path, value: strategy)
        }
        try await store(paths: pathTrie, storer: storer)
    }

    /// Store this Volume and only the nested Volumes selected by `paths`.
    func store(
        paths: ArrayTrie<StorageStrategy>,
        storer: any VolumeStorer
    ) async throws {
        if paths.get([]) == .recursive || paths.get([""]) == .recursive {
            try await storeRecursively(storer: storer)
            return
        }

        let node = try await storeCurrentVolume(storer: storer)
        try await node.storeVolumes(paths: paths, storer: storer)
    }

    /// Store only this complete Volume boundary.
    func store(storer: any VolumeStorer) async throws {
        _ = try await storeCurrentVolume(storer: storer)
    }

    /// Store this Volume and every materialized nested Volume independently.
    func storeRecursively(storer: any VolumeStorer) async throws {
        let node = try await storeCurrentVolume(storer: storer)
        try await node.storeVolumesRecursively(storer: storer)
    }

    /// Legacy block-at-a-time storage for ordinary `Storer` conformers.
    func storeRecursively(storer: Storer) throws {
        guard let node else { throw DataErrors.nodeNotAvailable }
        try storer.store(rawCid: rawCID, data: try serializedDataForStorage(storer: storer))
        try node.storeRecursively(storer: storer)
    }
}
