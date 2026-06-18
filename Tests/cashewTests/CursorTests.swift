import Testing
import Foundation
@testable import cashew

@Suite("Cursor / Iteration on MerkleDictionary")
struct CursorTests {

    @Suite("Sorted Keys")
    struct SortedKeysTests {

        @Test("sortedKeys returns keys in lexicographic order")
        func testSortedKeysOrder() throws {
            var dict = MerkleDictionaryImpl<String>()
            dict = try dict.inserting(key: "cherry", value: "c")
            dict = try dict.inserting(key: "apple", value: "a")
            dict = try dict.inserting(key: "banana", value: "b")
            dict = try dict.inserting(key: "date", value: "d")

            let keys = try dict.sortedKeys()
            #expect(keys == ["apple", "banana", "cherry", "date"])
        }

        @Test("sortedKeys with limit returns only that many")
        func testSortedKeysLimit() throws {
            var dict = MerkleDictionaryImpl<String>()
            dict = try dict.inserting(key: "cherry", value: "c")
            dict = try dict.inserting(key: "apple", value: "a")
            dict = try dict.inserting(key: "banana", value: "b")
            dict = try dict.inserting(key: "date", value: "d")

            let keys = try dict.sortedKeys(limit: 2)
            #expect(keys == ["apple", "banana"])
        }

        @Test("sortedKeys on empty dictionary returns empty")
        func testSortedKeysEmpty() throws {
            let dict = MerkleDictionaryImpl<String>()
            let keys = try dict.sortedKeys()
            #expect(keys.isEmpty)
        }

        @Test("sortedKeys with common prefixes maintains order")
        func testSortedKeysCommonPrefixes() throws {
            var dict = MerkleDictionaryImpl<String>()
            dict = try dict.inserting(key: "test", value: "1")
            dict = try dict.inserting(key: "testing", value: "2")
            dict = try dict.inserting(key: "tester", value: "3")
            dict = try dict.inserting(key: "team", value: "4")

            let keys = try dict.sortedKeys()
            #expect(keys == ["team", "test", "tester", "testing"])
        }
    }

    @Suite("Cursor Pagination")
    struct CursorPaginationTests {

        @Test("after parameter skips keys up to and including cursor")
        func testAfterCursor() throws {
            var dict = MerkleDictionaryImpl<String>()
            for ch in "abcdefghij" {
                dict = try dict.inserting(key: String(ch), value: "v")
            }

            let page = try dict.sortedKeys(after: "c")
            #expect(page == ["d", "e", "f", "g", "h", "i", "j"])
        }

        @Test("paginate through all keys")
        func testFullPagination() throws {
            var dict = MerkleDictionaryImpl<String>()
            let allExpected = (0..<20).map { String(format: "key_%02d", $0) }.sorted()
            for k in allExpected {
                dict = try dict.inserting(key: k, value: "v")
            }

            var collected = [String]()
            var cursor: String? = nil
            while true {
                let page = try dict.sortedKeys(limit: 5, after: cursor)
                if page.isEmpty { break }
                collected.append(contentsOf: page)
                cursor = page.last
            }

            #expect(collected == allExpected)
        }

        @Test("after cursor past all keys returns empty")
        func testAfterPastEnd() throws {
            var dict = MerkleDictionaryImpl<String>()
            dict = try dict.inserting(key: "alpha", value: "1")
            dict = try dict.inserting(key: "beta", value: "2")

            let keys = try dict.sortedKeys(after: "zzz")
            #expect(keys.isEmpty)
        }
    }

    @Suite("Sorted Keys and Values")
    struct SortedKeysAndValuesTests {

        @Test("sortedKeysAndValues returns pairs in lexicographic key order")
        func testSortedKeysAndValues() throws {
            var dict = MerkleDictionaryImpl<String>()
            dict = try dict.inserting(key: "cherry", value: "3")
            dict = try dict.inserting(key: "apple", value: "1")
            dict = try dict.inserting(key: "banana", value: "2")

            let pairs = try dict.sortedKeysAndValues()
            #expect(pairs.map(\.key) == ["apple", "banana", "cherry"])
            #expect(pairs.map(\.value) == ["1", "2", "3"])
        }

        @Test("sortedKeysAndValues with limit and after")
        func testSortedKeysAndValuesLimitAfter() throws {
            var dict = MerkleDictionaryImpl<String>()
            dict = try dict.inserting(key: "a", value: "1")
            dict = try dict.inserting(key: "b", value: "2")
            dict = try dict.inserting(key: "c", value: "3")
            dict = try dict.inserting(key: "d", value: "4")

            let pairs = try dict.sortedKeysAndValues(limit: 2, after: "a")
            #expect(pairs.map(\.key) == ["b", "c"])
            #expect(pairs.map(\.value) == ["2", "3"])
        }
    }

    @Suite("Cursor with Large Dictionary")
    struct LargeDictionaryTests {

        @Test("100+ keys paginated 10 at a time covers everything")
        func testLargePagination() throws {
            var dict = MerkleDictionaryImpl<String>()
            let allKeys = (0..<120).map { String(format: "item_%03d", $0) }.sorted()
            for k in allKeys {
                dict = try dict.inserting(key: k, value: "val")
            }

            var collected = [String]()
            var cursor: String? = nil
            while true {
                let page = try dict.sortedKeys(limit: 10, after: cursor)
                if page.isEmpty { break }
                collected.append(contentsOf: page)
                cursor = page.last
            }

            #expect(collected == allKeys)
            #expect(collected.count == 120)
        }

        @Test("sortedKeys returns strict lexicographic order for 100 random keys")
        func testLargeSortedOrder() throws {
            var dict = MerkleDictionaryImpl<String>()
            let keys = (0..<100).map { _ in
                String((0..<8).map { _ in "abcdefghijklmnopqrstuvwxyz".randomElement()! })
            }
            var uniqueKeys = Set<String>()
            for k in keys {
                if uniqueKeys.contains(k) { continue }
                uniqueKeys.insert(k)
                dict = try dict.inserting(key: k, value: "v")
            }

            let sorted = try dict.sortedKeys()
            #expect(sorted == sorted.sorted())
            #expect(sorted.count == uniqueKeys.count)
        }
    }
}
