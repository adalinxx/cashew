/// A ``Header`` whose node is a ``RadixNode``, forming the recursive CID-linked
/// structure of the radix trie. Each RadixHeader is both a parent's child reference
/// and the entry point to a subtree.
public protocol RadixHeader: Header where NodeType: RadixNode, NodeType.ChildType == Self { }
