public extension Volume {
    func storeRecursively(storer: Storer) throws {
        // Calling storage on a Volume root is a request to publish that complete
        // availability unit. An unresolved root cannot be published. Unresolved
        // nested Volumes are skipped by Node.storeRecursively because each nested
        // boundary is an independent availability unit.
        guard let node = node else { throw DataErrors.nodeNotAvailable }
        guard let nodeData = node.toData() else { throw DataErrors.serializationFailed }
        if let volumeAware = storer as? VolumeAwareStorer {
            try volumeAware.enterVolume(rootCID: rawCID)
            do {
                try volumeAware.store(rawCid: rawCID, data: nodeData)
                try node.storeRecursively(storer: volumeAware)
                try volumeAware.exitVolume(rootCID: rawCID)
            } catch {
                // A failed walk must never leave a scope that can later be flushed
                // as though it were a complete Volume. Preserve the original error.
                volumeAware.abortVolume(rootCID: rawCID)
                throw error
            }
        } else {
            try storer.store(rawCid: rawCID, data: nodeData)
            try node.storeRecursively(storer: storer)
        }
    }
}
