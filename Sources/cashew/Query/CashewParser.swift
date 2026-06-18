public struct CashewParser {
    public static func parse(_ input: String) throws -> [CashewExpression] {
        let tokens = try tokenize(input)
        if tokens.isEmpty { throw CashewQueryError.emptyExpression }
        return try parseExpressions(tokens)
    }

    static func tokenize(_ input: String) throws -> [Token] {
        var tokens = [Token]()
        var i = input.startIndex

        while i < input.endIndex {
            let ch = input[i]

            if ch.isWhitespace {
                i = input.index(after: i)
                continue
            }

            if ch == "|" {
                tokens.append(.pipe)
                i = input.index(after: i)
                continue
            }

            if ch == "=" {
                tokens.append(.equals)
                i = input.index(after: i)
                continue
            }

            if ch == "\"" || ch == "'" {
                let quote = ch
                i = input.index(after: i)
                var str = ""
                while i < input.endIndex && input[i] != quote {
                    if input[i] == "\\" && input.index(after: i) < input.endIndex {
                        i = input.index(after: i)
                    }
                    str.append(input[i])
                    i = input.index(after: i)
                }
                guard i < input.endIndex else {
                    throw CashewQueryError.parseError("Unterminated string literal")
                }
                i = input.index(after: i)
                tokens.append(.string(str))
                continue
            }

            if ch.isNumber || (ch == "-" && input.index(after: i) < input.endIndex && input[input.index(after: i)].isNumber) {
                var numStr = String(ch)
                i = input.index(after: i)
                while i < input.endIndex && input[i].isNumber {
                    numStr.append(input[i])
                    i = input.index(after: i)
                }
                guard let num = Int(numStr) else {
                    throw CashewQueryError.parseError("Invalid number: \(numStr)")
                }
                tokens.append(.number(num))
                continue
            }

            if ch.isLetter || ch == "_" {
                var word = String(ch)
                i = input.index(after: i)
                while i < input.endIndex && (input[i].isLetter || input[i].isNumber || input[i] == "_" || input[i] == "-") {
                    word.append(input[i])
                    i = input.index(after: i)
                }
                tokens.append(.word(word.lowercased()))
                continue
            }

            throw CashewQueryError.parseError("Unexpected character: '\(ch)'")
        }

        return tokens
    }

    static func parseExpressions(_ tokens: [Token]) throws -> [CashewExpression] {
        var segments = [[Token]]()
        var current = [Token]()
        for token in tokens {
            if case .pipe = token {
                if current.isEmpty { throw CashewQueryError.parseError("Empty expression before |") }
                segments.append(current)
                current = []
            } else {
                current.append(token)
            }
        }
        if current.isEmpty { throw CashewQueryError.parseError("Empty expression after |") }
        segments.append(current)

        return try segments.map { try parseSingle($0) }
    }

    static func parseSingle(_ tokens: [Token]) throws -> CashewExpression {
        guard let first = tokens.first, case .word(let command) = first else {
            throw CashewQueryError.parseError("Expected command")
        }

        let rest = Array(tokens.dropFirst())

        switch command {
        case "get":
            return try parseGet(rest)
        case "keys", "members":
            return try parseKeys(rest)
        case "values":
            return try parseValues(rest)
        case "count", "size":
            return .count
        case "contains", "has":
            return try parseContains(rest)
        case "first":
            return .first
        case "last":
            return .last
        case "insert", "add":
            return try parseAssignment(rest, kind: .insert)
        case "update":
            return try parseAssignment(rest, kind: .update)
        case "set", "put":
            return try parseAssignment(rest, kind: .set)
        case "delete", "remove":
            return try parseDelete(rest)
        case "append":
            return try parseAppend(rest)
        default:
            throw CashewQueryError.parseError("Unknown command: \(command)")
        }
    }

    enum AssignmentKind { case insert, update, set }

    static func parseGet(_ tokens: [Token]) throws -> CashewExpression {
        guard !tokens.isEmpty else {
            throw CashewQueryError.parseError("get requires a key or 'at <index>'")
        }
        if case .word("at") = tokens[0] {
            guard tokens.count >= 2, case .number(let n) = tokens[1] else {
                throw CashewQueryError.parseError("get at requires an index number")
            }
            return .getAt(n)
        }
        guard case .string(let key) = tokens[0] else {
            throw CashewQueryError.parseError("get requires a quoted key")
        }
        return .get(key)
    }

    static func parseKeys(_ tokens: [Token]) throws -> CashewExpression {
        if tokens.isEmpty { return .keys }
        guard case .word("sorted") = tokens[0] else {
            throw CashewQueryError.parseError("Expected 'sorted' after keys")
        }
        let (limit, after) = try parseLimitAfter(Array(tokens.dropFirst()))
        return .sortedKeys(limit: limit, after: after)
    }

    static func parseValues(_ tokens: [Token]) throws -> CashewExpression {
        if tokens.isEmpty { return .values }
        guard case .word("sorted") = tokens[0] else {
            throw CashewQueryError.parseError("Expected 'sorted' after values")
        }
        let (limit, after) = try parseLimitAfter(Array(tokens.dropFirst()))
        return .sortedValues(limit: limit, after: after)
    }

    static func parseLimitAfter(_ tokens: [Token]) throws -> (Int?, String?) {
        var limit: Int? = nil
        var after: String? = nil
        var i = 0
        while i < tokens.count {
            guard case .word(let kw) = tokens[i] else {
                throw CashewQueryError.parseError("Unexpected token")
            }
            if kw == "limit" {
                i += 1
                guard i < tokens.count, case .number(let n) = tokens[i] else {
                    throw CashewQueryError.parseError("limit requires a number")
                }
                limit = n
            } else if kw == "after" {
                i += 1
                guard i < tokens.count, case .string(let cursor) = tokens[i] else {
                    throw CashewQueryError.parseError("after requires a quoted string")
                }
                after = cursor
            } else {
                throw CashewQueryError.parseError("Unexpected keyword: \(kw)")
            }
            i += 1
        }
        return (limit, after)
    }

    static func parseContains(_ tokens: [Token]) throws -> CashewExpression {
        guard !tokens.isEmpty, case .string(let key) = tokens[0] else {
            throw CashewQueryError.parseError("contains requires a quoted key")
        }
        return .contains(key)
    }

    static func parseAssignment(_ tokens: [Token], kind: AssignmentKind) throws -> CashewExpression {
        guard tokens.count >= 3,
              case .string(let key) = tokens[0],
              case .equals = tokens[1],
              case .string(let value) = tokens[2] else {
            throw CashewQueryError.parseError("Expected: \"key\" = \"value\"")
        }
        switch kind {
        case .insert: return .insert(key: key, value: value)
        case .update: return .update(key: key, value: value)
        case .set: return .set(key: key, value: value)
        }
    }

    static func parseDelete(_ tokens: [Token]) throws -> CashewExpression {
        guard !tokens.isEmpty, case .string(let key) = tokens[0] else {
            throw CashewQueryError.parseError("delete requires a quoted key")
        }
        return .delete(key)
    }

    static func parseAppend(_ tokens: [Token]) throws -> CashewExpression {
        guard !tokens.isEmpty, case .string(let value) = tokens[0] else {
            throw CashewQueryError.parseError("append requires a quoted value")
        }
        return .append(value)
    }
}

enum Token: Equatable {
    case word(String)
    case string(String)
    case number(Int)
    case equals
    case pipe
}
