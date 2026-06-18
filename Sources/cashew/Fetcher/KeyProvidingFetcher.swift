/// A ``Fetcher`` that also provides decryption keys, enabling transparent
/// resolution of encrypted nodes.
public protocol KeyProvidingFetcher: Fetcher, KeyProvider {}
