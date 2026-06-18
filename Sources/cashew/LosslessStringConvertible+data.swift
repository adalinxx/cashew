import Foundation

/// UTF-8 `Data` serialization for any `LosslessStringConvertible` type.
public extension LosslessStringConvertible {
    func toData() -> Data? {
        return description.data(using: .utf8)
    }

    init?(data: Data) {
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        self.init(str)
    }
}
