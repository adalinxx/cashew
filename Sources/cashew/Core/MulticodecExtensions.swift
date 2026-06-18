import Foundation
@preconcurrency import Multicodec

/// Extension to provide convenient access to commonly used IPLD codecs
public extension Codecs {
    /// Commonly used IPLD codecs
    nonisolated(unsafe) static let ipldCodecs: [Codecs] = [
        .dag_json,
        .dag_cbor,
        .dag_pb,
        .raw,
        .cbor
    ]
    
    /// Finds a codec by its string name
    /// - Parameter name: The name of the codec (e.g., "dag-json", "dag-cbor")
    /// - Returns: The matching codec, or nil if not found
    static func codec(named name: String) -> Codecs? {
        return Codecs.allCases.first { $0.name == name }
    }
}
