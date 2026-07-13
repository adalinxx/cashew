extension Node {
    /// Store every ordinary owned child inside the currently active Volume and
    /// return materialized nested Volumes for independent storage after the parent
    /// boundary has successfully exited.
    ///
    /// Structural ownership follows the existing Cashew storage model:
    /// `properties()` lists child edges, Header-valued RadixNode values remain
    /// owned, `Volume` starts a new boundary, and `Reference` remains outside it.
    func storeWithinCurrentVolume(storer: VolumeAwareStorer) throws -> [any Header] {
        var nestedVolumes: [any Header] = []
        var materializedNestedRoots = Set<String>()

        func storeOwnedHeader(_ header: any Header) throws {
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

        for property in properties().sorted() {
            guard let header = get(property: property) else {
                throw DataErrors.missingDeclaredChild(property)
            }
            try storeOwnedHeader(header)
        }

        // RadixNode stores Header values outside properties(); they are still owned.
        if let radixNode = self as? any RadixNode,
           let value = radixNode.value,
           let header = value as? any Header {
            try storeOwnedHeader(header)
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
