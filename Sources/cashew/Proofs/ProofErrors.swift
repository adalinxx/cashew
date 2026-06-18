/// Errors from proof generation and verification operations.
public enum ProofErrors: Error {
    case invalidProofType(String)
    case proofFailed(String)
}
