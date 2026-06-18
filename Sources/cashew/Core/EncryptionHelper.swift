import Foundation
import Crypto

/// AES-256-GCM encryption and decryption utilities for node data.
public enum EncryptionHelper {
    public static func encrypt(data: Data, key: SymmetricKey) throws -> (encrypted: Data, iv: Data) {
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        guard let combined = sealedBox.combined else {
            throw DataErrors.encryptionFailed
        }
        let ivData = Data(nonce)
        return (encrypted: combined, iv: ivData)
    }

    public static func encrypt(data: Data, key: SymmetricKey, nonce: AES.GCM.Nonce) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        guard let combined = sealedBox.combined else {
            throw DataErrors.encryptionFailed
        }
        return combined
    }

    public static func decrypt(data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
