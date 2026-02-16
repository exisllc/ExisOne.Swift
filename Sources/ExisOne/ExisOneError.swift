import Foundation

/// Errors that can occur during ExisOne operations.
public enum ExisOneError: LocalizedError, Sendable {
    /// Base URL is missing or empty.
    case missingBaseURL
    /// Base URL must use HTTPS.
    case insecureBaseURL
    /// Base URL host is not in the allowed list.
    case hostNotAllowed(String)
    /// HTTP request failed with a status code.
    case httpError(statusCode: Int, message: String)
    /// Network error (no connectivity, timeout, etc).
    case networkError(String)
    /// Response could not be decoded.
    case decodingError(String)
    /// Offline validation is not configured (no public key).
    case offlineNotConfigured

    public var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "base_url is required"
        case .insecureBaseURL:
            return "base_url must use HTTPS"
        case .hostNotAllowed(let host):
            return "base_url host '\(host)' is not allowed"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .offlineNotConfigured:
            return "Offline validation not configured. Set offlinePublicKey in options."
        }
    }
}
