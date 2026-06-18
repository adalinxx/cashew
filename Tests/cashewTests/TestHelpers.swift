@testable import cashew
import Crypto
import Foundation

class TestStoreFetcher: Storer, Fetcher, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func store(rawCid: String, data: Data) {
        lock.withLock {
            storage[rawCid] = data
        }
    }

    func fetch(rawCid: String) async throws -> Data {
        let data = lock.withLock {
            storage[rawCid]
        }
        guard let data = data else { throw FetchError.notFound }
        return data
    }

    func storeRaw(rawCid: String, data: Data) {
        lock.withLock {
            storage[rawCid] = data
        }
    }
}

// Let the store fetchers double as a batched ContentSource so tests can drive
// the new resolve(source:) API (TestKeyProvidingStoreFetcher inherits this and
// also provides keys, exercising key forwarding through CoalescingFetcher).
extension TestStoreFetcher: ContentSource {
    func fetch(_ cids: Set<String>) async -> [String: Data] {
        var out: [String: Data] = [:]
        for cid in cids { if let d = try? await fetch(rawCid: cid) { out[cid] = d } }
        return out
    }
}

class TestKeyProvidingStoreFetcher: TestStoreFetcher, KeyProvidingFetcher {
    private let keyLock = NSLock()
    private var keys: [String: SymmetricKey] = [:]

    func registerKey(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let hash = SHA256.hash(data: keyData)
        let keyHash = Data(hash).base64EncodedString()
        keyLock.withLock {
            keys[keyHash] = key
        }
    }

    func key(for keyHash: String) -> SymmetricKey? {
        keyLock.withLock {
            keys[keyHash]
        }
    }
}

class CountingStoreFetcher: Storer, Fetcher, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    private var _fetchCount: Int = 0

    var fetchCount: Int {
        lock.withLock { _fetchCount }
    }

    func resetFetchCount() {
        lock.withLock { _fetchCount = 0 }
    }

    func store(rawCid: String, data: Data) {
        lock.withLock {
            storage[rawCid] = data
        }
    }

    func fetch(rawCid: String) async throws -> Data {
        let data = lock.withLock {
            _fetchCount += 1
            return storage[rawCid]
        }
        guard let data = data else { throw FetchError.notFound }
        return data
    }
}

enum FetchError: Error {
    case notFound
}

struct TestScalar: Scalar {
    let val: Int
    init(val: Int) { self.val = val }
}

typealias ScalarHeader = HeaderImpl<TestScalar>
typealias ScalarDict = MerkleDictionaryImpl<ScalarHeader>
typealias InnerDict = MerkleDictionaryImpl<HeaderImpl<MerkleDictionaryImpl<String>>>
typealias OuterDict = MerkleDictionaryImpl<HeaderImpl<InnerDict>>
