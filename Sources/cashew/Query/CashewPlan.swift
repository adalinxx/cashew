import ArrayTrie

public enum CashewStep {
    case transform(ArrayTrie<Transform>)
    case evaluate(CashewExpression)
}

public struct CashewPlan {
    public let steps: [CashewStep]

    public init(steps: [CashewStep]) {
        self.steps = steps
    }

    public static func compile(_ expressions: [CashewExpression]) -> CashewPlan {
        var steps = [CashewStep]()
        var transforms = ArrayTrie<Transform>()
        var hasTransforms = false
        var touchedKeys = Set<String>()

        func flush() {
            if hasTransforms {
                steps.append(.transform(transforms))
                transforms = ArrayTrie<Transform>()
                hasTransforms = false
                touchedKeys.removeAll()
            }
        }

        func addTransform(key: String, value: Transform) {
            if touchedKeys.contains(key) {
                flush()
            }
            transforms.set([key], value: value)
            touchedKeys.insert(key)
            hasTransforms = true
        }

        for expr in expressions {
            switch expr {
            case .insert(let key, let value):
                addTransform(key: key, value: .insert(value))
            case .update(let key, let value):
                addTransform(key: key, value: .update(value))
            case .delete(let key):
                addTransform(key: key, value: .delete)
            default:
                flush()
                steps.append(.evaluate(expr))
            }
        }

        flush()
        return CashewPlan(steps: steps)
    }

    public func resolutionPaths() -> ArrayTrie<ResolutionStrategy> {
        var paths = ArrayTrie<ResolutionStrategy>()
        for step in steps {
            switch step {
            case .transform:
                paths.set([""], value: .list)
            case .evaluate(let expr):
                switch expr {
                case .get(let key), .contains(let key), .set(let key, _):
                    paths.set([key], value: .targeted)
                case .keys, .sortedKeys, .values, .sortedValues:
                    paths.set([""], value: .recursive)
                case .count:
                    paths.set([""], value: .list)
                case .getAt, .first, .last, .append:
                    paths.set([""], value: .recursive)
                default:
                    break
                }
            }
        }
        return paths
    }
}
