import Foundation

/// Result of license activation.
public struct ActivationResult: Sendable {
    public let success: Bool
    public let errorCode: String?
    public let errorMessage: String?
    public let serverVersion: String?
    public let minimumRequiredVersion: String?
    public let licenseData: String?

    public init(
        success: Bool,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        serverVersion: String? = nil,
        minimumRequiredVersion: String? = nil,
        licenseData: String? = nil
    ) {
        self.success = success
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.serverVersion = serverVersion
        self.minimumRequiredVersion = minimumRequiredVersion
        self.licenseData = licenseData
    }
}

/// Result of online license validation.
public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let status: String
    public let expirationDate: Date?
    public let features: [String]
    public let serverVersion: String?
    public let minimumRequiredVersion: String?

    public init(
        isValid: Bool,
        status: String = "",
        expirationDate: Date? = nil,
        features: [String] = [],
        serverVersion: String? = nil,
        minimumRequiredVersion: String? = nil
    ) {
        self.isValid = isValid
        self.status = status
        self.expirationDate = expirationDate
        self.features = features
        self.serverVersion = serverVersion
        self.minimumRequiredVersion = minimumRequiredVersion
    }
}

/// Result of offline license validation.
public struct OfflineValidationResult: Sendable {
    public let isValid: Bool
    public let errorMessage: String?
    public let productName: String?
    public let productId: Int
    public let expirationDate: Date?
    public let email: String?
    public let features: [String]
    public let version: String?
    public let isExpired: Bool
    public let hardwareMismatch: Bool

    public init(
        isValid: Bool,
        errorMessage: String? = nil,
        productName: String? = nil,
        productId: Int = 0,
        expirationDate: Date? = nil,
        email: String? = nil,
        features: [String] = [],
        version: String? = nil,
        isExpired: Bool = false,
        hardwareMismatch: Bool = false
    ) {
        self.isValid = isValid
        self.errorMessage = errorMessage
        self.productName = productName
        self.productId = productId
        self.expirationDate = expirationDate
        self.email = email
        self.features = features
        self.version = version
        self.isExpired = isExpired
        self.hardwareMismatch = hardwareMismatch
    }
}

/// Result of smart validation (online or offline).
public struct SmartValidationResult: Sendable {
    public let isValid: Bool
    public let status: String
    public let expirationDate: Date?
    public let features: [String]
    public let wasOffline: Bool
    public let errorMessage: String?
    public let productName: String?
    public let serverVersion: String?
    public let minimumRequiredVersion: String?

    public init(
        isValid: Bool,
        status: String = "",
        expirationDate: Date? = nil,
        features: [String] = [],
        wasOffline: Bool = false,
        errorMessage: String? = nil,
        productName: String? = nil,
        serverVersion: String? = nil,
        minimumRequiredVersion: String? = nil
    ) {
        self.isValid = isValid
        self.status = status
        self.expirationDate = expirationDate
        self.features = features
        self.wasOffline = wasOffline
        self.errorMessage = errorMessage
        self.productName = productName
        self.serverVersion = serverVersion
        self.minimumRequiredVersion = minimumRequiredVersion
    }
}

/// Result of smart deactivation.
public struct DeactivationResult: Sendable {
    public let success: Bool
    public let serverNotified: Bool
    public let errorMessage: String?

    public init(
        success: Bool,
        serverNotified: Bool = false,
        errorMessage: String? = nil
    ) {
        self.success = success
        self.serverNotified = serverNotified
        self.errorMessage = errorMessage
    }
}

/// Payload embedded in offline activation codes.
struct OfflineKeyPayload {
    let productId: Int
    let productName: String
    let hardwareId: String
    let expirationDate: Date
    let email: String
    let features: [String]
    let tenantId: Int
    let version: String
}
