extension Node {
    /// Store every ordinary child inside the currently active Volume and
    /// return materialized nested Volumes for independent storage after the parent
    /// boundary has successfully exited.
    ///
    /// `properties()` lists same-boundary Headers, Header-valued RadixNode values
    /// are also same-boundary entries, `Volume` starts a new boundary, and
    /// `Reference` is not traversed by storage.
    func storeWithinCurrentVolume(storer: VolumeAwareStorer) throws -> [any Header] {
        var nestedVolumes: [any Header] = []
        var materializedNestedRoots = Set<String>()

        func storeHeaderInBoundary(_ header: any Header) throws {
            if header is any Volume {
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
            try storeHeaderInBoundary(header)
        }

        // RadixNode stores Header values outside properties(); they remain entries
        // in the current boundary.
        if let radixNode = self as? any RadixNode,
           let value = radixNode.value,
           let header = value as? any Header {
            try storeHeaderInBoundary(header)
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
            guard let header = get(property: property) else { continue }

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
