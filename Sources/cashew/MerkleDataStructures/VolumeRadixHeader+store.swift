public extension VolumeRadixHeader {
    func storeRecursively(storer: Storer) throws {
        guard node != nil else { throw DataErrors.nodeNotAvailable }
        if !(storer is VolumeAwareStorer), storer.contains(rawCid: rawCID) { return }
        try storeVolumeRecursively(storer: storer)
    }
}
