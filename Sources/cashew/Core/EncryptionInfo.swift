import Foundation
import Crypto

/// Metadata stored alongside an encrypted ``Header`` to enable decryption.
///
/// Contains the SHA-256 hash of the encryption key (for key lookup via
/// ``KeyProvider``) and the AES-GCM initialization vector.
public struct EncryptionInfo: Codable, Equatable, Sendable {
    public let keyHash: String
    public let iv: String

    public init(keyHash: String, iv: String) {
        self.keyHash = keyHash
        self.iv = iv
    }

    public init(key: SymmetricKey, iv: Data) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let hash = SHA256.hash(data: keyData)
        self.keyHash = Data(hash).base64EncodedString()
        self.iv = iv.base64EncodedString()
    }

    public var ivData: Data? {
        Data(base64Encoded: iv)
    }
}
