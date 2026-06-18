public extension MerkleDictionary where ValueType: LosslessStringConvertible {
    func diff(from old: Self) throws -> CashewDiff {
        let oldKVs = try old.allKeysAndValues()
        let newKVs = try self.allKeysAndValues()
        let oldKeys = Set(oldKVs.keys)
        let newKeys = Set(newKVs.keys)
        var result = CashewDiff()

        for key in newKeys.subtracting(oldKeys) {
            result.inserted[key] = "\(newKVs[key]!)"
        }

        for key in oldKeys.subtracting(newKeys) {
            result.deleted[key] = "\(oldKVs[key]!)"
        }

        for key in oldKeys.intersection(newKeys) {
            let oldVal = oldKVs[key]!
            let newVal = newKVs[key]!
            let oldStr = "\(oldVal)"
            let newStr = "\(newVal)"
            if oldStr != newStr {
                if let oldH = oldVal as? any Header, let newH = newVal as? any Header {
                    let childDiff = diffHeaders(oldH, newH)
                    result.modified[key] = .init(old: oldH.rawCID, new: newH.rawCID, children: childDiff)
                } else {
                    result.modified[key] = .init(old: oldStr, new: newStr)
                }
            }
        }

        return result
    }
}
