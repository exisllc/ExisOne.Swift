import Foundation

/// Configuration options for ``ExisOneClient``.
public struct ExisOneClientOptions: Sendable {

    /// Base URL for the ExisOne API (must use HTTPS).
    ///
    /// Falls back to `EXISONE_BASEURL` environment variable if empty.
    public var baseURL: String

    /// API access token for authentication (`ExisOneApi <token>` scheme).
    public var accessToken: String

    /// RSA public key in PEM format for offline license validation.
    ///
    /// Obtain from `GET /api/crypto/keys/public`.
    public var offlinePublicKey: String?

    /// If set, restricts ``baseURL`` to these hosts only.
    public var allowedBaseURLHosts: [String]?

    /// Request timeout in seconds. Default: 30.
    public var timeout: TimeInterval

    public init(
        baseURL: String = "",
        accessToken: String = "",
        offlinePublicKey: String? = nil,
        allowedBaseURLHosts: [String]? = nil,
        timeout: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.offlinePublicKey = offlinePublicKey
        self.allowedBaseURLHosts = allowedBaseURLHosts
        self.timeout = timeout
    }
}
