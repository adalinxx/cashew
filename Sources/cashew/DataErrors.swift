/// Errors from data serialization, CID computation, encryption, and structural storage traversal.
public enum DataErrors: Error {
    case nodeNotAvailable
    /// `Node.properties()` declared an owned child that `get(property:)` did not return.
    /// A complete-Volume traversal cannot silently omit that child.
    case missingDeclaredChild(String)
    case serializationFailed
    case cidCreationFailed
    case cidMismatch
    case encryptionFailed
    case decryptionFailed
    case keyNotFound
    case invalidIV
}
