import Foundation

/// Client for ExisOne Software Activation System.
///
/// Provides async methods for license activation, validation, deactivation,
/// offline validation, and smart validation.
///
/// ```swift
/// let client = ExisOneClient(
///     baseURL: "https://www.exisone.com",
///     accessToken: "exo_at_xxx_yyy"
/// )
///
/// let hwid = ExisOneHardwareId.generate()
/// let result = try await client.validate(
///     hardwareId: hwid,
///     productName: "MyApp",
///     activationKey: "XXXX-XXXX-XXXX-XXXX"
/// )
///
/// if result.isValid {
///     print("Licensed! Features: \(result.features)")
/// }
/// ```
public final class ExisOneClient: Sendable {

    /// SDK version.
    public static let version = "0.7.0"

    private let options: ExisOneClientOptions
    private let session: URLSession

    // MARK: - Initialization

    /// Create a client with full options.
    public init(options: ExisOneClientOptions) throws {
        var opts = options

        // Check environment variable if base URL not set
        if opts.baseURL.isEmpty {
            opts.baseURL = ProcessInfo.processInfo.environment["EXISONE_BASEURL"] ?? ""
        }

        try Self.validateBaseURL(opts.baseURL, allowed: opts.allowedBaseURLHosts)

        self.options = opts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = opts.timeout
        self.session = URLSession(configuration: config)
    }

    /// Convenience: create a client with just the essentials.
    public convenience init(baseURL: String = "https://www.exisone.com", accessToken: String) throws {
        try self.init(options: ExisOneClientOptions(baseURL: baseURL, accessToken: accessToken))
    }

    // MARK: - Hardware ID

    /// Generate a hardware fingerprint for this machine.
    ///
    /// - Returns: 64-character uppercase hex string (SHA-256 hash).
    public static func generateHardwareId() -> String {
        ExisOneHardwareId.generate()
    }

    // MARK: - Activation

    /// Activate a license on this machine.
    ///
    /// - Parameters:
    ///   - activationKey: The activation key to activate.
    ///   - email: User's email address.
    ///   - hardwareId: Hardware fingerprint from ``generateHardwareId()``.
    ///   - productName: Name of the product.
    ///   - version: Optional client version string for version enforcement.
    /// - Returns: Activation result with success status and any error details.
    public func activate(
        activationKey: String,
        email: String,
        hardwareId: String,
        productName: String,
        version: String? = nil
    ) async -> ActivationResult {
        var payload: [String: Any] = [
            "activationKey": activationKey,
            "email": email,
            "hardwareId": hardwareId,
            "productName": productName
        ]
        if let version { payload["version"] = version }

        do {
            let (data, response) = try await post("/api/license/activate", body: payload)
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return ActivationResult(
                    success: false,
                    errorCode: json["error"] as? String,
                    errorMessage: json["message"] as? String ?? "HTTP \(http.statusCode)",
                    serverVersion: json["serverVersion"] as? String,
                    minimumRequiredVersion: json["minimumRequiredVersion"] as? String
                )
            }

            return ActivationResult(
                success: true,
                serverVersion: json["serverVersion"] as? String,
                minimumRequiredVersion: json["minimumRequiredVersion"] as? String,
                licenseData: String(data: data, encoding: .utf8)
            )
        } catch {
            return ActivationResult(success: false, errorMessage: "Network error: \(error.localizedDescription)")
        }
    }

    // MARK: - Validation

    /// Validate a license online.
    ///
    /// - Parameters:
    ///   - activationKey: The activation key to validate (omit for trial check).
    ///   - hardwareId: Hardware fingerprint.
    ///   - productName: Product name (required for trial validation).
    ///   - version: Optional client version string for version enforcement.
    /// - Returns: Validation result with license status, features, and expiration.
    /// - Throws: ``ExisOneError`` on network or HTTP errors.
    public func validate(
        hardwareId: String,
        productName: String? = nil,
        activationKey: String? = nil,
        version: String? = nil
    ) async throws -> ValidationResult {
        var payload: [String: Any] = ["hardwareId": hardwareId]
        if let activationKey { payload["activationKey"] = activationKey }
        if let productName { payload["productName"] = productName }
        if let version { payload["version"] = version }

        let (data, response) = try await post("/api/license/validate", body: payload)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw ExisOneError.httpError(statusCode: http.statusCode, message: text)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExisOneError.decodingError("Invalid JSON response")
        }

        let isValid = json["isValid"] as? Bool ?? false
        let status = json["status"] as? String ?? (isValid ? "licensed" : "invalid")
        let features = json["features"] as? [String] ?? []

        var expirationDate: Date?
        if let expStr = json["expirationDate"] as? String {
            expirationDate = parseISO8601Date(expStr)
        }

        return ValidationResult(
            isValid: isValid,
            status: status,
            expirationDate: expirationDate,
            features: features,
            serverVersion: json["serverVersion"] as? String,
            minimumRequiredVersion: json["minimumRequiredVersion"] as? String
        )
    }

    // MARK: - Deactivation

    /// Deactivate a license.
    ///
    /// - Parameters:
    ///   - activationKey: The activation key to deactivate.
    ///   - hardwareId: Hardware fingerprint.
    ///   - productName: Name of the product.
    /// - Returns: `true` if deactivation succeeded.
    /// - Throws: ``ExisOneError`` on network or HTTP errors.
    @discardableResult
    public func deactivate(
        activationKey: String,
        hardwareId: String,
        productName: String
    ) async throws -> Bool {
        let payload: [String: Any] = [
            "licenseKey": activationKey,
            "hardwareId": hardwareId,
            "productName": productName
        ]

        let (data, response) = try await post("/api/license/deactivate", body: payload)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw ExisOneError.httpError(statusCode: http.statusCode, message: text)
        }

        return true
    }

    // MARK: - Key generation (admin)

    /// Generate a new activation key (requires admin token).
    ///
    /// - Parameters:
    ///   - productName: Name of the product.
    ///   - email: User's email address.
    ///   - planId: Optional plan ID.
    ///   - validityDays: Optional validity period in days.
    /// - Returns: The generated activation key.
    /// - Throws: ``ExisOneError`` on failure.
    public func generateActivationKey(
        productName: String,
        email: String,
        planId: Int? = nil,
        validityDays: Int? = nil
    ) async throws -> String {
        var payload: [String: Any] = [
            "productName": productName,
            "email": email
        ]
        if let planId { payload["planId"] = planId }
        if let validityDays { payload["validityDays"] = validityDays }

        let (data, response) = try await post("/api/activationkey/generate", body: payload)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw ExisOneError.httpError(statusCode: http.statusCode, message: text)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Features

    /// Get licensed features as an array of strings.
    ///
    /// - Parameter activationKey: The activation key.
    /// - Returns: Array of feature names.
    /// - Throws: ``ExisOneError`` on failure.
    public func getLicensedFeatures(activationKey: String) async throws -> [String] {
        let payload: [String: Any] = ["activationKey": activationKey]
        let (data, response) = try await post("/api/license/features/csv", body: payload)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw ExisOneError.httpError(statusCode: http.statusCode, message: text)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let csv = json["features"] as? String else {
            return []
        }

        return csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Support tickets

    /// Submit a support ticket.
    ///
    /// - Parameters:
    ///   - productName: Name of the product.
    ///   - email: User's email address.
    ///   - subject: Ticket subject.
    ///   - message: Ticket message body.
    /// - Throws: ``ExisOneError`` on failure.
    public func sendSupportTicket(
        productName: String,
        email: String,
        subject: String,
        message: String
    ) async throws {
        let payload: [String: Any] = [
            "productName": productName,
            "email": email,
            "subject": subject,
            "message": message
        ]

        let (data, response) = try await post("/api/support/ticket", body: payload)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw ExisOneError.httpError(statusCode: http.statusCode, message: text)
        }
    }

    // MARK: - Offline validation

    /// Validate an offline activation code locally without a server connection.
    ///
    /// Requires ``ExisOneClientOptions/offlinePublicKey`` to be set.
    ///
    /// - Parameters:
    ///   - offlineCode: The offline activation code (Base32 with dashes).
    ///   - hardwareId: The hardware ID to validate against.
    /// - Returns: Offline validation result with license details.
    public func validateOffline(offlineCode: String, hardwareId: String) -> OfflineValidationResult {
        ExisOne.validateOffline(
            offlineCode: offlineCode,
            hardwareId: hardwareId,
            publicKeyPEM: options.offlinePublicKey ?? ""
        )
    }

    // MARK: - Smart validation

    /// Smart validation that auto-detects offline vs online keys.
    ///
    /// - Offline keys (>= 50 chars after cleaning) are validated locally first.
    /// - Online keys are validated with the server.
    /// - Falls back to offline validation if the server is unreachable.
    ///
    /// - Parameters:
    ///   - keyOrCode: Either an online activation key or offline code.
    ///   - hardwareId: Hardware fingerprint.
    ///   - productName: Product name (for online validation).
    /// - Returns: Smart validation result.
    public func validateSmart(
        keyOrCode: String,
        hardwareId: String,
        productName: String? = nil
    ) async -> SmartValidationResult {
        // Detect offline key by length
        if isOfflineKey(keyOrCode) {
            let offlineResult = validateOffline(offlineCode: keyOrCode, hardwareId: hardwareId)

            // Opportunistic server sync (fire and forget)
            if offlineResult.isValid {
                Task {
                    _ = try? await validate(hardwareId: hardwareId, activationKey: keyOrCode)
                }
            }

            let status: String
            if !offlineResult.isValid {
                status = offlineResult.isExpired ? "expired" : "invalid"
            } else {
                status = "licensed"
            }

            return SmartValidationResult(
                isValid: offlineResult.isValid,
                status: status,
                expirationDate: offlineResult.expirationDate,
                features: offlineResult.features,
                wasOffline: true,
                errorMessage: offlineResult.errorMessage,
                productName: offlineResult.productName
            )
        }

        // Online key - try server first
        do {
            let result = try await validate(
                hardwareId: hardwareId,
                productName: productName,
                activationKey: keyOrCode
            )
            return SmartValidationResult(
                isValid: result.isValid,
                status: result.status,
                expirationDate: result.expirationDate,
                features: result.features,
                wasOffline: false,
                productName: productName,
                serverVersion: result.serverVersion,
                minimumRequiredVersion: result.minimumRequiredVersion
            )
        } catch {
            // Server unreachable - try offline fallback
            if options.offlinePublicKey != nil {
                let offlineResult = validateOffline(offlineCode: keyOrCode, hardwareId: hardwareId)
                return SmartValidationResult(
                    isValid: offlineResult.isValid,
                    status: offlineResult.isValid ? "licensed" : "invalid",
                    expirationDate: offlineResult.expirationDate,
                    features: offlineResult.features,
                    wasOffline: true,
                    errorMessage: offlineResult.isValid ? nil : "Server unreachable and offline validation failed",
                    productName: offlineResult.productName
                )
            }

            return SmartValidationResult(
                isValid: false,
                status: "offline",
                wasOffline: true,
                errorMessage: "Server unreachable and no offline validation available"
            )
        }
    }

    // MARK: - Smart deactivation

    /// Deactivate a license with opportunistic online sync.
    ///
    /// Attempts to notify the server, but succeeds even if offline.
    ///
    /// - Parameters:
    ///   - keyOrCode: The key to deactivate.
    ///   - hardwareId: Hardware fingerprint.
    ///   - productName: Name of the product.
    /// - Returns: Deactivation result.
    public func deactivateSmart(
        keyOrCode: String,
        hardwareId: String,
        productName: String
    ) async -> DeactivationResult {
        do {
            try await deactivate(
                activationKey: keyOrCode,
                hardwareId: hardwareId,
                productName: productName
            )
            return DeactivationResult(success: true, serverNotified: true)
        } catch is URLError {
            return DeactivationResult(
                success: true,
                serverNotified: false,
                errorMessage: "License deactivated locally. Server will be notified when connection is restored."
            )
        } catch {
            return DeactivationResult(
                success: false,
                serverNotified: false,
                errorMessage: error.localizedDescription
            )
        }
    }

    // MARK: - HTTP internals

    private func post(_ path: String, body: [String: Any]) async throws -> (Data, URLResponse) {
        guard let url = URL(string: options.baseURL + path) else {
            throw ExisOneError.missingBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !options.accessToken.isEmpty {
            request.setValue("ExisOneApi \(options.accessToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            return try await session.data(for: request)
        } catch {
            throw ExisOneError.networkError(error.localizedDescription)
        }
    }

    private static func validateBaseURL(_ url: String, allowed: [String]?) throws {
        guard !url.isEmpty else { throw ExisOneError.missingBaseURL }
        guard url.hasPrefix("https://") else { throw ExisOneError.insecureBaseURL }

        if let allowed, let host = URL(string: url)?.host, !allowed.contains(host) {
            throw ExisOneError.hostNotAllowed(host)
        }
    }

    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df.date(from: string.replacingOccurrences(of: "Z", with: ""))
    }
}
