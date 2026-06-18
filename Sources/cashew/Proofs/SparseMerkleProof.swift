/// The type of proof requested for a key in a ``MerkleDictionary``.
///
/// Used with `proof(paths:fetcher:)` to specify what evidence to collect
/// for each targeted key path.
public enum SparseMerkleProof: Int, Codable, Sendable {
    case insertion = 1, mutation, deletion, existence
}

