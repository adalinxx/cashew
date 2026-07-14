public extension VolumeRadixHeader {
    func storeRecursively(storer: Storer) throws {
        guard let node else { return }
        if storer.contains(rawCid: rawCID) { return }
        try storer.store(rawCid: rawCID, data: try serializedDataForStorage(storer: storer))
        try node.storeRecursively(storer: storer)
    }
}
