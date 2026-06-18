import Crypto

/// Provides symmetric encryption keys by their SHA-256 hash.
/// Used during resolution to decrypt encrypted nodes.
public protocol KeyProvider {
    func key(for keyHash: String) -> SymmetricKey?
}
