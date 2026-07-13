extension Node {
    /// Store every ordinary owned child inside the currently active Volume and
    /// return materialized nested Volumes for independent storage after the parent
    /// boundary has successfully exited.
    ///
    /// Structural ownership is determined entirely by the existing Cashew model:
    /// `properties()` lists owned children, `Volume` starts a new boundary, and
    /// `Reference` is not a Header and therefore never appears in this walk.
    func storeWithinCurrentVolume(storer: VolumeAwareStorer) throws -> [any Header] {
        var nestedVolumes: [any Header] = []
        var materializedNestedRoots = Set<String>()

        for property in properties().sorted() {
            guard let header = get(property: property) else {
                throw DataErrors.missingDeclaredChild(property)
            }

            if header is any Volume {
                // The ownership edge is stable even when the nested Volume's bytes
                // are not locally materialized. Availability of the child is separate.
                try storer.includeNestedVolume(rootCID: header.rawCID)

                if header.node != nil,
                   materializedNestedRoots.insert(header.rawCID).inserted {
                    nestedVolumes.append(header)
                }
            } else {
                let descendants = try header.storeWithinCurrentVolume(storer: storer)
                for nested in descendants
                    where materializedNestedRoots.insert(nested.rawCID).inserted {
                    nestedVolumes.append(nested)
                }
            }
        }

        return nestedVolumes
    }
}

public extension Node {
    func storeRecursively(storer: Storer) throws {
        // Generic best-effort recursion for callers that did not enter through a
        // Volume root. The strict complete-Volume path uses
        // `storeWithinCurrentVolume(storer:)` above so it can close the current
        // boundary before independently storing nested Volumes.
        var volumeChildren: [any Header] = []
        for property in properties().sorted() {
            guard let header = get(property: property) else {
                if storer is VolumeAwareStorer {
                    throw DataErrors.missingDeclaredChild(property)
                }
                continue
            }

            if header is any Volume {
                if header.node != nil {
                    volumeChildren.append(header)
                }
            } else {
                try header.storeRecursively(storer: storer)
            }
        }

        for header in volumeChildren {
            try header.storeRecursively(storer: storer)
        }
    }
}
