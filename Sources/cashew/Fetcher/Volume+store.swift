public extension Volume {
    func storeRecursively(storer: Storer) throws {
        guard let node = node else { return }
        guard let nodeData = node.toData() else { throw DataErrors.serializationFailed }
        if let volumeAware = storer as? VolumeAwareStorer {
            try volumeAware.enterVolume(rootCID: rawCID)
            try volumeAware.store(rawCid: rawCID, data: nodeData)
            try node.storeRecursively(storer: volumeAware)
            try volumeAware.exitVolume(rootCID: rawCID)
        } else {
            try storer.store(rawCid: rawCID, data: nodeData)
            try node.storeRecursively(storer: storer)
        }
    }
}
