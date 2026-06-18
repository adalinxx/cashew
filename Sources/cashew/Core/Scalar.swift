import Foundation

/// A leaf ``Node`` with no children.
///
/// Provides default no-op implementations for all ``Node`` traversal and update
/// methods. Conforming types only need their stored properties:
/// ```swift
/// struct UserProfile: Scalar {
///     let name: String
///     let email: String
/// }
/// ```
public protocol Scalar: Node { }

public extension Scalar {
    func get(property: String) -> (any Header)? { nil }
    func properties() -> Set<PathSegment> { [] }
    func set(property: PathSegment, to child: any Header) -> Self { self }
    func set(properties: [PathSegment: any Header]) -> Self { self }
}

