import XCTest
@testable import ExisOne

final class ExisOneTests: XCTestCase {

    // MARK: - CrockfordBase32

    func testBase32DecodesEmpty() {
        let result = CrockfordBase32.decode("")
        XCTAssertTrue(result.isEmpty)
    }

    func testBase32DecodesKnownValues() {
        // "f" -> Base32 "CR" (ASCII 102 = 0b01100110)
        // C = 12, R = 25 -> 01100 11001 -> 01100110 0(1) -> [102] with leftover
        let result = CrockfordBase32.decode("CR")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], 102) // ASCII 'f'
    }

    func testBase32SkipsInvalidChars() {
        // Dashes and spaces should be silently ignored
        let withDashes = CrockfordBase32.decode("C-R")
        let withoutDashes = CrockfordBase32.decode("CR")
        XCTAssertEqual(withDashes, withoutDashes)
    }

    func testBase32IsCaseInsensitive() {
        let upper = CrockfordBase32.decode("CR")
        let lower = CrockfordBase32.decode("cr")
        XCTAssertEqual(upper, lower)
    }

    // MARK: - Client initialization

    func testClientRequiresHTTPS() {
        XCTAssertThrowsError(try ExisOneClient(baseURL: "http://example.com", accessToken: "tok")) { error in
            guard let exisError = error as? ExisOneError else { XCTFail(); return }
            if case .insecureBaseURL = exisError { /* expected */ } else { XCTFail("Wrong error: \(exisError)") }
        }
    }

    func testClientRequiresBaseURL() {
        XCTAssertThrowsError(try ExisOneClient(baseURL: "", accessToken: "tok")) { error in
            guard let exisError = error as? ExisOneError else { XCTFail(); return }
            if case .missingBaseURL = exisError { /* expected */ } else { XCTFail("Wrong error: \(exisError)") }
        }
    }

    func testClientInitializesWithHTTPS() {
        XCTAssertNoThrow(try ExisOneClient(baseURL: "https://www.exisone.com", accessToken: "tok"))
    }

    func testClientHostAllowList() {
        let options = ExisOneClientOptions(
            baseURL: "https://evil.com",
            accessToken: "tok",
            allowedBaseURLHosts: ["www.exisone.com"]
        )
        XCTAssertThrowsError(try ExisOneClient(options: options)) { error in
            guard let exisError = error as? ExisOneError else { XCTFail(); return }
            if case .hostNotAllowed = exisError { /* expected */ } else { XCTFail("Wrong error: \(exisError)") }
        }
    }

    // MARK: - Hardware ID

    func testHardwareIdIsStable() {
        let id1 = ExisOneHardwareId.generate()
        let id2 = ExisOneHardwareId.generate()
        XCTAssertEqual(id1, id2, "Hardware ID should be stable across calls")
    }

    func testHardwareIdIs64Hex() {
        let id = ExisOneHardwareId.generate()
        XCTAssertEqual(id.count, 64)
        XCTAssertTrue(id.allSatisfy { $0.isHexDigit })
        XCTAssertEqual(id, id.uppercased(), "Should be uppercase hex")
    }

    // MARK: - Offline key detection

    func testOfflineKeyDetection() {
        // Short online key
        XCTAssertFalse(isOfflineKey("XXXX-XXXX-XXXX-XXXX"))
        // Long offline code
        let longCode = String(repeating: "A", count: 60)
        XCTAssertTrue(isOfflineKey(longCode))
    }

    // MARK: - Offline validation without public key

    func testOfflineValidationWithoutKey() {
        let result = validateOffline(offlineCode: "SOMECODE", hardwareId: "HW123", publicKeyPEM: "")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
        XCTAssertTrue(result.errorMessage!.contains("not configured"))
    }

    // MARK: - Model defaults

    func testActivationResultDefaults() {
        let result = ActivationResult(success: true)
        XCTAssertTrue(result.success)
        XCTAssertNil(result.errorCode)
        XCTAssertNil(result.errorMessage)
    }

    func testValidationResultDefaults() {
        let result = ValidationResult(isValid: false)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.status, "")
        XCTAssertTrue(result.features.isEmpty)
    }

    func testSmartValidationResultDefaults() {
        let result = SmartValidationResult(isValid: false, status: "offline", wasOffline: true)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.wasOffline)
    }

    func testDeactivationResultDefaults() {
        let result = DeactivationResult(success: true, serverNotified: true)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.serverNotified)
    }

    // MARK: - Version

    func testSDKVersion() {
        XCTAssertEqual(ExisOneClient.version, "0.7.0")
    }
}
