import Foundation

public extension Header {
    /// Walk this resolved header's owned subtree once, reporting each newly-visited
    /// node CID together with its parent→child edge multiset (child CID → multiplicity).
    ///
    /// Children come from the structural `Node.properties()`/`get(property:)` surface —
    /// the same edges `storeRecursively` follows — so the visited node set is identical
    /// to the one a recursive store produces. `Reference` back/shared links are NOT
    /// children and are never walked, so the walk never climbs backward into unrelated
    /// history.
    ///
    /// `visited` dedups shared subtrees and lets callers exclude an already-walked
    /// frontier (seed it with the nodes to skip). A node already in `visited` is not
    /// revisited and `visit` is not called for it. `visit` is invoked in post-order
    /// (after a node's children have been walked).
    func walkOwnedSubtree(
        visited: inout Set<String>,
        visit: (_ node: String, _ childEdges: [String: Int]) -> Void
    ) {
        guard let node = node else { return }
        let parent = rawCID
        if visited.contains(parent) { return }   // already walked (dedup shared subtrees)
        visited.insert(parent)
        var childEdges: [String: Int] = [:]
        for property in node.properties() {
            guard let child = node.get(property: property) else { continue }
            childEdges[child.rawCID, default: 0] += 1
            child.walkOwnedSubtree(visited: &visited, visit: visit)
        }
        visit(parent, childEdges)
    }
}
