@preconcurrency import Crypto

/// Specifies how encryption is applied to nodes in a Merkle tree.
///
/// - ``targeted(_:)``: Encrypt only explicitly marked leaf values.
/// - ``list(_:)``: Encrypt all direct children (one level).
/// - ``recursive(_:)``: Encrypt the entire subtree.
public enum EncryptionStrategy: @unchecked Sendable {
    case targeted(SymmetricKey)
    case list(SymmetricKey)
    case recursive(SymmetricKey)

    public var key: SymmetricKey {
        switch self {
        case .targeted(let key): return key
        case .list(let key): return key
        case .recursive(let key): return key
        }
    }
}
