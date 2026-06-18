/// A ``Storer`` that receives context when a ``Volume`` boundary is crossed
/// during recursive storage.
///
/// Before writing the child CIDs that make up a Volume's contiguous data,
/// the walker calls ``provide(rootCID:)`` so the storer can group per-Volume
/// writes for locality (e.g., batched sequential disk append) and downstream
/// systems can index which Volume root each non-boundary CID belongs to.
public protocol VolumeAwareStorer: Storer {
    func enterVolume(rootCID: String) throws
    func exitVolume(rootCID: String) throws
}

public extension VolumeAwareStorer {
    func exitVolume(rootCID: String) throws {}
}
