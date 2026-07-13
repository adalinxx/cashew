public extension Node {
    func storeRecursively(storer: Storer) throws {
        // Store non-Volume children first so they land in the current volume's
        // buffer group. If a Volume child is stored first it calls enterVolume
        // on the storer, sealing the current buffer and starting a new group —
        // any non-Volume siblings processed after that would be lost from the
        // enclosing volume's group (stored in the Volume child's group instead).
        let props = properties()
        var volumeChildren: [any Header] = []
        for property in props {
            guard let header = get(property: property) else { continue }
            if header is any Volume {
                // A nested Volume is an independent availability unit. Its CID is
                // already committed by this node's serialized bytes, so an absent
                // nested Volume does not make the enclosing Volume partial. Store
                // it independently only when its own node is materialized.
                if header.node != nil {
                    volumeChildren.append(header)
                }
            } else {
                // Non-Volume properties are owned by the current boundary. The
                // Header storage implementation fails closed when one is unresolved
                // during a Volume-aware traversal.
                try header.storeRecursively(storer: storer)
            }
        }
        for header in volumeChildren {
            try header.storeRecursively(storer: storer)
        }
    }
}
