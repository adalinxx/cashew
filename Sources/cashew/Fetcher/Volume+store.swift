import Foundation

extension Volume {
    func storeVolumeRecursively(storer: Storer) throws {
        // Calling storage on a Volume root is a request to publish that complete
        // availability unit. An unresolved root cannot be published.
        guard let node else { throw DataErrors.nodeNotAvailable }
        let dataToStore = try serializedDataForStorage(storer: storer)

        if let volumeAware = storer as? VolumeAwareStorer {
            let nestedVolumes: [any Header]
            do {
                // Entry itself is covered by the abort path. A conformer that
                // allocates its scope before throwing must still be cleaned up.
                try volumeAware.enterVolume(rootCID: rawCID)
                try volumeAware.store(rawCid: rawCID, data: dataToStore)
                nestedVolumes = try node.storeWithinCurrentVolume(storer: volumeAware)
                try volumeAware.exitVolume(rootCID: rawCID)
            } catch {
                // A failed walk must never leave a scope that can later be flushed
                // as though it were a complete Volume. Preserve the original error.
                volumeAware.abortVolume(rootCID: rawCID)
                throw error
            }

            // A nested Volume is an independent availability unit. The parent has
            // already completed its ordinary contents; a materialized child is then
            // stored under its own lifecycle without changing the parent boundary.
            for nested in nestedVolumes {
                try nested.storeRecursively(storer: volumeAware)
            }
        } else {
            try storer.store(rawCid: rawCID, data: dataToStore)
            try node.storeRecursively(storer: storer)
        }
    }
}

public extension Volume {
    func storeRecursively(storer: Storer) throws {
        try storeVolumeRecursively(storer: storer)
    }
}
