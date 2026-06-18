import Testing
import Foundation
import ArrayTrie
@testable import cashew

@Suite("Merkle Dictionary Operations")
struct MerkleDictionaryTests {

    struct TestValue: Scalar {
        let val: Int

        init(val: Int) {
            self.val = val
        }
    }

    @Suite("Dictionary Operations")
    struct DictionaryOperations {

        @Test("MerkleDictionary get(property:) with single char key works")
        func testMerkleDictionaryGetPropertySingleChar() throws {
            let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
                .inserting(key: "alice", value: "val1")

            let result = dict.get(property: "a")
            #expect(result != nil)
        }

        @Test("MerkleDictionary get(property:) with empty key returns nil")
        func testMerkleDictionaryGetPropertyEmptyKey() throws {
            let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
                .inserting(key: "alice", value: "val1")

            let result = dict.get(property: "")
            #expect(result == nil)
        }

        @Test("MerkleDictionary get(property:) with multi-char key uses first char")
        func testMerkleDictionaryGetPropertyMultiCharKey() throws {
            let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
                .inserting(key: "alice", value: "val1")

            let result = dict.get(property: "alice")
            #expect(result != nil)
        }

        @Test("RadixNode set(property:to:) actually updates the child")
        func testRadixNodeSetPropertyToUpdatesChild() throws {
            typealias DictType = MerkleDictionaryImpl<String>

            let dict = try DictType(children: [:], count: 0)
                .inserting(key: "alice", value: "val1")
                .inserting(key: "bob", value: "val2")

            let aliceChild = dict.children["a"]!
            let bobChild = dict.children["b"]!

            let aliceNode = aliceChild.node!
            let result = aliceNode.set(property: "b", to: bobChild)

            #expect(result.children["b"] != nil)
        }

        @Test("RadixNode set(property:to:) with empty property returns self")
        func testRadixNodeSetPropertyToEmptyPropertyReturnsSelf() throws {
            typealias DictType = MerkleDictionaryImpl<String>

            let dict = try DictType(children: [:], count: 0)
                .inserting(key: "alice", value: "val1")

            let aliceChild = dict.children["a"]!
            let aliceNode = aliceChild.node!
            let result = aliceNode.set(property: "", to: aliceChild)
            #expect(result.prefix == aliceNode.prefix)
            #expect(result.children.count == aliceNode.children.count)
        }

        @Test("Deleting single child node uses safe unwrap")
        func testDeletingSingleChildNodeSafeUnwrap() throws {
            let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
                .inserting(key: "abc", value: "val1")
                .inserting(key: "abd", value: "val2")

            let result = try dict.deleting(key: "abd")
            #expect(result.count == 1)
            #expect(try result.get(key: "abc") == "val1")
        }

        @Test("Basic dictionary operations still work after fixes")
        func testBasicDictionaryOperationsRegression() throws {
            let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
                .inserting(key: "key1", value: "value1")
                .inserting(key: "key2", value: "value2")
                .inserting(key: "key3", value: "value3")

            #expect(dict.count == 3)
            #expect(try dict.get(key: "key1") == "value1")
            #expect(try dict.get(key: "key2") == "value2")
            #expect(try dict.get(key: "key3") == "value3")

            let deleted = try dict.deleting(key: "key2")
            #expect(deleted.count == 2)
            #expect(try deleted.get(key: "key2") == nil)

            let mutated = try dict.mutating(key: ArraySlice("key1"), value: "updated1")
            #expect(mutated.count == 3)
            #expect(try mutated.get(key: "key1") == "updated1")
        }

        @Test("Keys that force deep radix splitting and collapsing")
        func testDeepRadixSplittingAndCollapsing() throws {
            var dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
            dict = try dict.inserting(key: "abcdefghij", value: "long1")
            dict = try dict.inserting(key: "abcdefghik", value: "long2")
            dict = try dict.inserting(key: "abcdefgxyz", value: "mid_split")
            dict = try dict.inserting(key: "abcXYZ", value: "early_split")
            dict = try dict.inserting(key: "aZZZ", value: "very_early_split")

            #expect(dict.count == 5)
            #expect(try dict.get(key: "abcdefghij") == "long1")
            #expect(try dict.get(key: "abcdefghik") == "long2")
            #expect(try dict.get(key: "abcdefgxyz") == "mid_split")
            #expect(try dict.get(key: "abcXYZ") == "early_split")
            #expect(try dict.get(key: "aZZZ") == "very_early_split")

            let deleted = try dict
                .deleting(key: "abcdefghik")
                .deleting(key: "abcdefgxyz")
            #expect(deleted.count == 3)
            #expect(try deleted.get(key: "abcdefghij") == "long1")
            #expect(try deleted.get(key: "abcXYZ") == "early_split")

            var transforms = ArrayTrie<Transform>()
            transforms.set(["abcdefghij"], value: .update("updated_long"))
            transforms.set(["abcMNO"], value: .insert("new_mid"))
            let result = try deleted.transform(transforms: transforms)!
            #expect(result.count == 4)
            #expect(try result.get(key: "abcdefghij") == "updated_long")
            #expect(try result.get(key: "abcMNO") == "new_mid")
            #expect(try result.get(key: "abcXYZ") == "early_split")
            #expect(try result.get(key: "aZZZ") == "very_early_split")
        }

        @Test("Single-character keys and two-character keys coexist")
        func testShortKeyCoexistence() throws {
            var dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
            dict = try dict.inserting(key: "a", value: "just_a")
            dict = try dict.inserting(key: "ab", value: "a_then_b")
            dict = try dict.inserting(key: "abc", value: "a_then_b_then_c")
            dict = try dict.inserting(key: "b", value: "just_b")
            dict = try dict.inserting(key: "ba", value: "b_then_a")

            #expect(dict.count == 5)
            #expect(try dict.get(key: "a") == "just_a")
            #expect(try dict.get(key: "ab") == "a_then_b")
            #expect(try dict.get(key: "abc") == "a_then_b_then_c")
            #expect(try dict.get(key: "b") == "just_b")
            #expect(try dict.get(key: "ba") == "b_then_a")

            let deleted = try dict.deleting(key: "ab")
            #expect(deleted.count == 4)
            #expect(try deleted.get(key: "a") == "just_a")
            #expect(try deleted.get(key: "ab") == nil)
            #expect(try deleted.get(key: "abc") == "a_then_b_then_c")
        }
    }

    @Suite("Key Enumeration")
    struct KeyEnumeration {

        @Test("MerkleDictionary allKeys returns all inserted keys")
        func testMerkleDictionaryAllKeys() throws {
            typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>

            let testValue1 = TestValue(val: 1)
            let testValue2 = TestValue(val: 2)
            let testValue3 = TestValue(val: 3)
            let testValue4 = TestValue(val: 4)

            let header1 = try HeaderImpl(node: testValue1)
            let header2 = try HeaderImpl(node: testValue2)
            let header3 = try HeaderImpl(node: testValue3)
            let header4 = try HeaderImpl(node: testValue4)

            let dictionary = try TestDictionaryType()
                .inserting(key: "foo", value: header1)
                .inserting(key: "bar", value: header2)
                .inserting(key: "foobar", value: header3)
                .inserting(key: "baz", value: header4)

            let allKeys = try dictionary.allKeys()

            #expect(allKeys.count == 4)
            #expect(allKeys.contains("foo"))
            #expect(allKeys.contains("bar"))
            #expect(allKeys.contains("foobar"))
            #expect(allKeys.contains("baz"))
        }

        @Test("MerkleDictionary allKeys works with empty dictionary")
        func testMerkleDictionaryAllKeysEmpty() throws {
            typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>

            let emptyDictionary = TestDictionaryType()
            let allKeys = try emptyDictionary.allKeys()

            #expect(allKeys.isEmpty)
        }

        @Test("MerkleDictionary allKeys works with single key")
        func testMerkleDictionaryAllKeysSingle() throws {
            typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>

            let testValue = TestValue(val: 42)
            let header = try HeaderImpl(node: testValue)

            let dictionary = try TestDictionaryType().inserting(key: "single", value: header)
            let allKeys = try dictionary.allKeys()

            #expect(allKeys.count == 1)
            #expect(allKeys.contains("single"))
        }

        @Test("MerkleDictionary allKeysAndValues returns all key-value pairs")
        func testMerkleDictionaryAllKeysAndValues() throws {
            typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>

            let testValue1 = TestValue(val: 100)
            let testValue2 = TestValue(val: 200)
            let testValue3 = TestValue(val: 300)
            let testValue4 = TestValue(val: 400)

            let header1 = try HeaderImpl(node: testValue1)
            let header2 = try HeaderImpl(node: testValue2)
            let header3 = try HeaderImpl(node: testValue3)
            let header4 = try HeaderImpl(node: testValue4)

            let dictionary = try TestDictionaryType()
                .inserting(key: "alpha", value: header1)
                .inserting(key: "beta", value: header2)
                .inserting(key: "gamma", value: header3)
                .inserting(key: "delta", value: header4)

            let allKeysAndValues = try dictionary.allKeysAndValues()

            #expect(allKeysAndValues.count == 4)
            #expect(allKeysAndValues["alpha"]?.node?.val == 100)
            #expect(allKeysAndValues["beta"]?.node?.val == 200)
            #expect(allKeysAndValues["gamma"]?.node?.val == 300)
            #expect(allKeysAndValues["delta"]?.node?.val == 400)
        }

        @Test("MerkleDictionary allKeysAndValues works with empty dictionary")
        func testMerkleDictionaryAllKeysAndValuesEmpty() throws {
            typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>

            let emptyDictionary = TestDictionaryType()
            let allKeysAndValues = try emptyDictionary.allKeysAndValues()

            #expect(allKeysAndValues.isEmpty)
        }

        @Test("MerkleDictionary allKeysAndValues works with single key-value pair")
        func testMerkleDictionaryAllKeysAndValuesSingle() throws {
            typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>

            let testValue = TestValue(val: 999)
            let header = try HeaderImpl(node: testValue)

            let dictionary = try TestDictionaryType().inserting(key: "only", value: header)
            let allKeysAndValues = try dictionary.allKeysAndValues()

            #expect(allKeysAndValues.count == 1)
            #expect(allKeysAndValues["only"]?.node?.val == 999)
        }

        @Test("MerkleDictionary allKeysAndValues handles keys with common prefixes")
        func testMerkleDictionaryAllKeysAndValuesCommonPrefixes() throws {
            typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>

            let testValue1 = TestValue(val: 10)
            let testValue2 = TestValue(val: 20)
            let testValue3 = TestValue(val: 30)

            let header1 = try HeaderImpl(node: testValue1)
            let header2 = try HeaderImpl(node: testValue2)
            let header3 = try HeaderImpl(node: testValue3)

            let dictionary = try TestDictionaryType()
                .inserting(key: "test", value: header1)
                .inserting(key: "testing", value: header2)
                .inserting(key: "tester", value: header3)

            let allKeysAndValues = try dictionary.allKeysAndValues()

            #expect(allKeysAndValues.count == 3)
            #expect(allKeysAndValues["test"]?.node?.val == 10)
            #expect(allKeysAndValues["testing"]?.node?.val == 20)
            #expect(allKeysAndValues["tester"]?.node?.val == 30)
        }

        @Test("MerkleDictionary allKeys throws nodeNotAvailable for unpopulated headers")
        func testMerkleDictionaryAllKeysThrowsForUnpopulatedNodes() throws {
            typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
            typealias TestHeaderType = HeaderImpl<TestValue>

            let unpopulatedHeader = TestHeaderType(rawCID: "test_cid")
            var dictionary = TestDictionaryType()
            dictionary = TestDictionaryType(children: ["a": RadixHeaderImpl(rawCID: unpopulatedHeader.rawCID)], count: 1)

            #expect(throws: DataErrors.nodeNotAvailable) {
                try dictionary.allKeys()
            }
        }

        @Test("MerkleDictionary allKeysAndValues throws nodeNotAvailable for unpopulated headers")
        func testMerkleDictionaryAllKeysAndValuesThrowsForUnpopulatedNodes() throws {
            typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
            typealias TestHeaderType = HeaderImpl<TestValue>

            let unpopulatedHeader = TestHeaderType(rawCID: "test_cid")
            var dictionary = TestDictionaryType()
            dictionary = TestDictionaryType(children: ["b": RadixHeaderImpl(rawCID: unpopulatedHeader.rawCID)], count: 1)

            #expect(throws: DataErrors.nodeNotAvailable) {
                try dictionary.allKeysAndValues()
            }
        }
    }
}
