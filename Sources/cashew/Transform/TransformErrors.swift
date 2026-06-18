/// Errors from applying ``Transform`` operations to a Merkle data structure.
public enum TransformErrors: Error {
    case transformFailed(String)
    case invalidKey(String)
    case missingData(String)
}
