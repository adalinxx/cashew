/// Controls how a storage plan crosses a Volume boundary.
public enum StorageStrategy: Equatable, Sendable {
    /// Store the Volume at this path, but no nested Volumes below it.
    case targeted

    /// Store the Volume at this path and every materialized nested Volume.
    case recursive
}
