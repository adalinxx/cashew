/// A ``Storer`` that receives context when a ``Volume`` boundary is crossed
/// during recursive storage.
///
/// A Volume is an atomic availability unit. `enterVolume` begins collecting the
/// complete owned contents of that boundary and `exitVolume` commits that scope
/// to the storer's completed-volume set. Conformers must implement both methods:
/// silently ignoring `exitVolume` makes it possible to present a partially
/// traversed scope as a stored Volume.
///
/// If traversal throws before `exitVolume`, the active scope must be abandoned
/// and must never be published as a complete Volume.
public protocol VolumeAwareStorer: Storer {
    func enterVolume(rootCID: String) throws
    func exitVolume(rootCID: String) throws
}
