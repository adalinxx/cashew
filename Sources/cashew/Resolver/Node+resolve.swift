import ArrayTrie

public extension Node {
    func resolveRecursive(fetcher: Fetcher) async throws -> Self {
        let newProperties = try await withThrowingTaskGroup(of: (PathSegment, any Header).self) { group in
            for property in properties() {
                group.addTask {
                    guard let address = get(property: property) else { throw ResolutionErrors.typeError("missing property during resolution") }
                    if let volume = address as? any Volume {
                        return (property, try await volume.resolveRecursive(fetcher: fetcher))
                    }
                    let resolved = try await address.resolveRecursive(fetcher: fetcher)
                    return (property, resolved)
                }
            }
            var result = [PathSegment: any Header]()
            for try await (key, value) in group {
                result[key] = value
            }
            return result
        }
        return set(properties: newProperties)
    }

    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self {
        let box = SendableBox(paths)
        let newProperties = try await withThrowingTaskGroup(of: (PathSegment, any Header)?.self) { group in
            for property in properties() {
                group.addTask {
                    let paths = box.value
                    guard let address = get(property: property) else { return nil }

                    if paths.get([property]) == .recursive {
                        if let volume = address as? any Volume {
                            return (property, try await volume.resolveRecursive(fetcher: fetcher))
                        }
                        let resolved = try await address.resolveRecursive(fetcher: fetcher)
                        return (property, resolved)
                    }
                    else if let nextPaths = paths.traverse([property]) {
                        if !nextPaths.isEmpty {
                            if let volume = address as? any Volume {
                                return (property, try await volume.resolve(paths: nextPaths, fetcher: fetcher))
                            }
                            let resolved = try await address.resolve(paths: nextPaths, fetcher: fetcher)
                            return (property, resolved)
                        }
                        else if paths.get([property]) == .targeted {
                            if let volume = address as? any Volume {
                                return (property, try await volume.resolve(fetcher: fetcher))
                            }
                            let resolved = try await address.resolve(fetcher: fetcher)
                            return (property, resolved)
                        }
                        else {
                            return (property, address)
                        }
                    }
                    else {
                        return (property, address)
                    }
                }
            }
            var result = [PathSegment: any Header]()
            for try await pair in group {
                if let (key, value) = pair {
                    result[key] = value
                }
            }
            return result
        }
        return set(properties: newProperties)
    }
}
