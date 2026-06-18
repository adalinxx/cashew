/// Errors from resolving lazy ``Header`` references via a ``Fetcher``.
public enum ResolutionErrors: Error {
    case typeError(String)
}
