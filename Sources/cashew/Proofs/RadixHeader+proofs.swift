public extension RadixHeader {
    func resolveChildren(fetcher: Fetcher) async throws -> Self {
        if let node = node {
            let newNode = try await node.resolveChildren(fetcher: fetcher)
            return Self(rawCID: rawCID, node: newNode, encryptionInfo: encryptionInfo)
        }
        else {
            let node = try await fetchAndDecodeNode(fetcher: fetcher)
            let newNode = try await node.resolveChildren(fetcher: fetcher)
            return Self(rawCID: rawCID, node: newNode, encryptionInfo: encryptionInfo)
        }
    }
}
