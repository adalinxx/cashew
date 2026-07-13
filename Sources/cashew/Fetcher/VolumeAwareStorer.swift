/// A ``Storer`` that receives lifecycle events for one complete ``Volume``.
///
/// A Volume is an atomic availability unit. ``enterVolume(rootCID:)`` begins an
/// in-memory scope, ``exitVolume(rootCID:)`` publishes the successfully traversed
/// scope, and ``abortVolume(rootCID:)`` discards it when traversal throws.
///
/// Conformers MUST NOT publish an entered scope unless the matching exit succeeds.
/// This keeps "Volume available" binary: a complete Volume is present or it is not.
public protocol VolumeAwareStorer: Storer {
    func enterVolume(rootCID: String) throws
    func exitVolume(rootCID: String) throws

    /// Abandon the active scope for `rootCID` after a failed traversal.
    ///
    /// This method is deliberately non-throwing: it is invoked while propagating
    /// the original storage error and must leave no partially traversed scope that
    /// a later flush could mistake for a complete Volume.
    func abortVolume(rootCID: String)
}
