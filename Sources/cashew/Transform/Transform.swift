/// A mutation operation applied to a key in a ``MerkleDictionary``.
///
/// Transforms are organized in an `ArrayTrie<Transform>` where each path
/// identifies the target key and the value specifies the operation.
public enum Transform: Equatable {
    /// Insert a new value (encoded as its `LosslessStringConvertible` description) at the key.
    case insert(String)
    /// Update an existing value at the key.
    case update(String)
    /// Delete the value at the key.
    case delete
}
