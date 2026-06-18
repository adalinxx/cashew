struct SortedEntry<Value: Codable>: Codable {
    let key: String
    let value: Value
}
