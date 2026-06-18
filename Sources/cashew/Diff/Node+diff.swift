public extension Node {
    func diff(from old: Self) -> CashewDiff {
        let oldKeys = old.properties()
        let newKeys = properties()
        var result = CashewDiff()

        for key in oldKeys.subtracting(newKeys) {
            if let header = old.get(property: key) {
                result.deleted[key] = header.rawCID
            }
        }

        for key in newKeys.subtracting(oldKeys) {
            if let header = get(property: key) {
                result.inserted[key] = header.rawCID
            }
        }

        for key in oldKeys.intersection(newKeys) {
            guard let oldHeader = old.get(property: key),
                  let newHeader = get(property: key) else { continue }
            if oldHeader.rawCID != newHeader.rawCID {
                let childDiff = diffHeaders(oldHeader, newHeader)
                result.modified[key] = .init(
                    old: oldHeader.rawCID,
                    new: newHeader.rawCID,
                    children: childDiff
                )
            }
        }

        return result
    }
}

func diffHeaders(_ old: any Header, _ new: any Header) -> CashewDiff {
    if old.rawCID == new.rawCID { return CashewDiff() }
    func open<H: Header>(_ oldH: H) -> CashewDiff {
        guard let oldNode = oldH.node,
              let newH = new as? H,
              let newNode = newH.node else {
            return CashewDiff()
        }
        return newNode.diff(from: oldNode)
    }
    return open(old)
}
