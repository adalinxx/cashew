/// A ``RadixHeader`` that is also a ``Volume`` — every trie-internal link is a
/// Volume boundary. Used to build Merkle tries where the liveness unit is the
/// individual trie node, not the outer root: pinning the root pins its direct
/// Volume children, pinning each subtree pins that subtree's Volume children,
/// and so on recursively.
///
/// Pairing this with ``VolumeMerkleDictionary`` produces a structure in which
/// *every* header — root and all descendants — is independently addressable as
/// a Volume boundary, enabling per-subtree retention and contiguous storage
/// grouping (via the store-side ``VolumeAwareStorer``).
public protocol VolumeRadixHeader: RadixHeader, Volume
where NodeType.ChildType == Self { }
