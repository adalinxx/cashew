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
                volumeChildren.append(header)
            } else {
                try header.storeRecursively(storer: storer)
            }
        }
        for header in volumeChildren {
            try header.storeRecursively(storer: storer)
        }
    }
}
