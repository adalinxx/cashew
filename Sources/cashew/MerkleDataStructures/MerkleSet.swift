/// A content-addressed set backed by a ``MerkleDictionary`` with empty string values.
///
/// Provides standard set algebra operations (union, intersection, subtraction,
/// symmetric difference) where each member is a string key.
public protocol MerkleSet: MerkleDictionary where ValueType == String {}

public extension MerkleSet {
    func insert(_ member: String) throws -> Self {
        return try inserting(key: member, value: "")
    }

    func remove(_ member: String) throws -> Self {
        return try deleting(key: member)
    }

    func contains(_ member: String) throws -> Bool {
        return try get(key: member) != nil
    }

    func members() throws -> Set<String> {
        return try allKeys()
    }

    func union(_ other: Self) throws -> Self {
        let otherMembers = try other.members()
        var result = self
        for member in otherMembers {
            if try !result.contains(member) {
                result = try result.insert(member)
            }
        }
        return result
    }

    func intersection(_ other: Self) throws -> Self {
        let selfMembers = try members()
        var result = Self()
        for member in selfMembers {
            if try other.contains(member) {
                result = try result.insert(member)
            }
        }
        return result
    }

    func subtracting(_ other: Self) throws -> Self {
        let otherMembers = try other.members()
        var result = self
        for member in otherMembers {
            if try result.contains(member) {
                result = try result.remove(member)
            }
        }
        return result
    }

    func symmetricDifference(_ other: Self) throws -> Self {
        let selfMembers = try members()
        let otherMembers = try other.members()
        var result = Self()
        for member in selfMembers {
            if !otherMembers.contains(member) {
                result = try result.insert(member)
            }
        }
        for member in otherMembers {
            if !selfMembers.contains(member) {
                result = try result.insert(member)
            }
        }
        return result
    }
}
