import Foundation
import Security

/// Minimum length to detect offline keys (online keys are ~19 chars like XXXX-XXXX-XXXX-XXXX).
let offlineKeyMinLength = 50

/// Check if a key appears to be an offline activation code based on length.
func isOfflineKey(_ key: String) -> Bool {
    let clean = key.replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: " ", with: "")
    return clean.count >= offlineKeyMinLength
}

/// Validate an offline activation code locally without a server connection.
///
/// - Parameters:
///   - offlineCode: The offline activation code (Base32 with dashes).
///   - hardwareId: The hardware ID to validate against.
///   - publicKeyPEM: RSA public key in PEM format.
/// - Returns: Validation result with license details.
func validateOffline(
    offlineCode: String,
    hardwareId: String,
    publicKeyPEM: String
) -> OfflineValidationResult {
    guard !publicKeyPEM.isEmpty else {
        return OfflineValidationResult(
            isValid: false,
            errorMessage: "Offline validation not configured. Set offlinePublicKey in options."
        )
    }

    guard !offlineCode.isEmpty else {
        return OfflineValidationResult(isValid: false, errorMessage: "Offline code is required")
    }

    guard !hardwareId.isEmpty else {
        return OfflineValidationResult(isValid: false, errorMessage: "Hardware ID is required")
    }

    do {
        guard let payload = try parseOfflineCode(publicKeyPEM: publicKeyPEM, code: offlineCode) else {
            return OfflineValidationResult(
                isValid: false,
                errorMessage: "Invalid or tampered offline activation code"
            )
        }

        // Check hardware ID match (case-insensitive)
        if payload.hardwareId.uppercased() != hardwareId.uppercased() {
            return OfflineValidationResult(
                isValid: false,
                errorMessage: "Hardware ID mismatch. This code is bound to a different machine.",
                productName: payload.productName,
                expirationDate: payload.expirationDate,
                hardwareMismatch: true
            )
        }

        // Check expiration
        if payload.expirationDate < Date() {
            return OfflineValidationResult(
                isValid: false,
                errorMessage: "License has expired",
                productName: payload.productName,
                productId: payload.productId,
                expirationDate: payload.expirationDate,
                email: payload.email,
                features: payload.features,
                version: payload.version,
                isExpired: true
            )
        }

        return OfflineValidationResult(
            isValid: true,
            productName: payload.productName,
            productId: payload.productId,
            expirationDate: payload.expirationDate,
            email: payload.email,
            features: payload.features,
            version: payload.version
        )
    } catch {
        return OfflineValidationResult(
            isValid: false,
            errorMessage: "Error validating offline code: \(error.localizedDescription)"
        )
    }
}

// MARK: - Internal parsing

/// Parse and verify an offline activation code.
private func parseOfflineCode(publicKeyPEM: String, code: String) throws -> OfflineKeyPayload? {
    // Remove dashes and whitespace, uppercase
    let clean = code
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: " ", with: "")
        .uppercased()

    // Decode from Crockford Base32
    let combined = CrockfordBase32.decode(clean)
    guard combined.count >= 4 else { return nil }

    // Extract payload length (2 bytes, little-endian)
    let payloadLength = Int(combined[0]) | (Int(combined[1]) << 8)
    guard combined.count >= 2 + payloadLength + 1 else { return nil }

    // Extract payload and signature
    let payloadBytes = combined[2 ..< 2 + payloadLength]
    let signature = combined[(2 + payloadLength)...]

    // Verify RSA-SHA256 signature
    guard verifyRSASignature(
        publicKeyPEM: publicKeyPEM,
        data: Data(payloadBytes),
        signature: Data(signature)
    ) else {
        return nil
    }

    // Deserialize JSON payload
    guard let json = try? JSONSerialization.jsonObject(with: Data(payloadBytes)) as? [String: Any] else {
        return nil
    }

    // Parse expiration date
    let expDate: Date
    if let expStr = json["expirationDate"] as? String {
        expDate = parseISO8601(expStr) ?? .distantPast
    } else {
        expDate = .distantPast
    }

    let features: [String]
    if let arr = json["features"] as? [String] {
        features = arr
    } else {
        features = []
    }

    return OfflineKeyPayload(
        productId: json["productId"] as? Int ?? 0,
        productName: json["productName"] as? String ?? "",
        hardwareId: json["hardwareId"] as? String ?? "",
        expirationDate: expDate,
        email: json["email"] as? String ?? "",
        features: features,
        tenantId: json["tenantId"] as? Int ?? 0,
        version: json["version"] as? String ?? ""
    )
}

// MARK: - RSA signature verification

/// Verify an RSA-SHA256 (PKCS#1 v1.5) signature using Security.framework.
private func verifyRSASignature(publicKeyPEM: String, data: Data, signature: Data) -> Bool {
    // Strip PEM headers and decode Base64
    let stripped = publicKeyPEM
        .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
        .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
        .replacingOccurrences(of: "\n", with: "")
        .replacingOccurrences(of: "\r", with: "")
        .trimmingCharacters(in: .whitespaces)

    guard let keyData = Data(base64Encoded: stripped) else { return false }

    let attributes: [CFString: Any] = [
        kSecAttrKeyType: kSecAttrKeyTypeRSA,
        kSecAttrKeyClass: kSecAttrKeyClassPublic
    ]

    var error: Unmanaged<CFError>?
    guard let secKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
        return false
    }

    let algorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256

    guard SecKeyIsAlgorithmSupported(secKey, .verify, algorithm) else { return false }

    return SecKeyVerifySignature(
        secKey,
        algorithm,
        data as CFData,
        signature as CFData,
        &error
    )
}

// MARK: - Date parsing

/// Parse an ISO-8601 date string (handles Z suffix and various formats).
private func parseISO8601(_ string: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: string) { return date }

    // Try without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: string) { return date }

    // Try basic format
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(identifier: "UTC")
    df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return df.date(from: string.replacingOccurrences(of: "Z", with: ""))
}
