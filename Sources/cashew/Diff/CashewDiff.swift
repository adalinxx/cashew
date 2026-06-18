public struct CashewDiff: Sendable, Equatable, CustomStringConvertible {
    public var inserted: [String: String] = [:]
    public var deleted: [String: String] = [:]
    public var modified: [String: ModifiedEntry] = [:]

    public struct ModifiedEntry: Sendable, Equatable {
        public var old: String
        public var new: String
        public var children: CashewDiff

        public init(old: String, new: String, children: CashewDiff = CashewDiff()) {
            self.old = old
            self.new = new
            self.children = children
        }
    }

    public var isEmpty: Bool {
        inserted.isEmpty && deleted.isEmpty && modified.isEmpty
    }

    public var changeCount: Int {
        inserted.count + deleted.count + modified.values.reduce(0) { total, entry in
            let childCount = entry.children.changeCount
            return total + (childCount > 0 ? childCount : 1)
        }
    }

    public init(
        inserted: [String: String] = [:],
        deleted: [String: String] = [:],
        modified: [String: ModifiedEntry] = [:]
    ) {
        self.inserted = inserted
        self.deleted = deleted
        self.modified = modified
    }

    public var description: String {
        var lines = [String]()
        render(into: &lines, indent: 0)
        return lines.joined(separator: "\n")
    }

    private func render(into lines: inout [String], indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        for (key, value) in inserted.sorted(by: { $0.key < $1.key }) {
            lines.append("\(pad)+ \(key): \(value)")
        }
        for (key, value) in deleted.sorted(by: { $0.key < $1.key }) {
            lines.append("\(pad)- \(key): \(value)")
        }
        for (key, entry) in modified.sorted(by: { $0.key < $1.key }) {
            if entry.children.isEmpty {
                lines.append("\(pad)~ \(key): \(entry.old) → \(entry.new)")
            } else {
                lines.append("\(pad)~ \(key):")
                entry.children.render(into: &lines, indent: indent + 1)
            }
        }
    }
}
