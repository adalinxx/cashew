/// A ``MerkleDictionary`` whose top-level children (and, recursively, all
/// internal trie links) are ``VolumeRadixHeader``s — so every header in the
/// constructed trie is a ``Volume``.
///
/// Used for lattice state so liveness and pinning can operate at trie-node
/// granularity instead of only at the outer state root. When the state root is
/// wrapped in a ``VolumeImpl``, the full tree forms a chain of Volume
/// boundaries where each subtree can be independently pinned, fetched, and
/// garbage-collected.
public protocol VolumeMerkleDictionary: MerkleDictionary
where ChildType: VolumeRadixHeader { }
