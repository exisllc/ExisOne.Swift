# ExisOne Swift SDK

Native Swift package for integrating [ExisOne](https://www.exisone.com) software licensing into macOS and iOS applications.

## Features

- **Hardware Fingerprinting** - IOKit-based hardware ID generation (no subprocess calls)
- **License Activation & Validation** - Full async/await API
- **Offline Licensing** - RSA-SHA256 validation via Security.framework for air-gapped environments
- **Smart Validation** - Auto-detects online vs offline keys with graceful fallback
- **Feature Gating** - Check which features are enabled per license
- **Support Tickets** - Submit tickets directly from your app
- **Zero Dependencies** - Uses only Apple frameworks (CryptoKit, Security, IOKit)
- **Swift Concurrency** - All types conform to `Sendable`

## Requirements

| | Minimum |
|---|---------|
| Swift | 5.9+ |
| macOS | 12+ |
| iOS | 15+ |
| Xcode | 15+ |

## Installation

### Swift Package Manager (Xcode)

1. **File > Add Package Dependencies...**
2. Enter: `https://github.com/exisllc/ExisOne.Swift`
3. Select version **0.7.0** (or "Up to Next Major")
4. Add **ExisOne** to your target

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/exisllc/ExisOne.Swift", from: "0.7.0")
]
```

Then add the dependency to your target:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "ExisOne", package: "ExisOne.Swift")
])
```

## Quick Start

```swift
import ExisOne

// Initialize the client
let client = try ExisOneClient(
    baseURL: "https://www.exisone.com",
    accessToken: "exo_at_xxx_yyy"
)

// Generate a hardware fingerprint for this Mac
let hwid = ExisOneHardwareId.generate()

// Activate a license
let activation = await client.activate(
    activationKey: "XXXX-XXXX-XXXX-XXXX",
    email: "user@example.com",
    hardwareId: hwid,
    productName: "MyApp"
)

// Validate on app launch
let result = try await client.validate(
    hardwareId: hwid,
    productName: "MyApp",
    activationKey: "XXXX-XXXX-XXXX-XXXX"
)

if result.isValid {
    print("Licensed until: \(result.expirationDate ?? Date())")
    print("Features: \(result.features)")
}
```

## Hardware ID

Generates a stable 64-character hex fingerprint using native macOS APIs:

- **IOKit** - `IOPlatformUUID` (same as System Information > Hardware UUID)
- **Network** - MAC addresses via `getifaddrs()`
- **System** - Architecture, CPU count, hostname, OS version
- **Hash** - SHA-256 with salt for consistency across SDK versions

```swift
let hwid = ExisOneHardwareId.generate()
// "D7391D68656651079189364C9BB7D4642C97B5B05D10B44FD4CA5B8D4723A682"
```

The same Mac always produces the same ID.

## SwiftUI Integration

```swift
import SwiftUI
import ExisOne

struct ContentView: View {
    @State private var isLicensed = false
    @State private var features: [String] = []

    var body: some View {
        VStack {
            if isLicensed {
                Text("Licensed")
                if features.contains("Pro") {
                    ProFeaturesView()
                }
            } else {
                ActivationView()
            }
        }
        .task { await checkLicense() }
    }

    func checkLicense() async {
        let client = try? ExisOneClient(
            baseURL: "https://www.exisone.com",
            accessToken: "exo_at_xxx_yyy"
        )
        guard let client else { return }

        let hwid = ExisOneHardwareId.generate()
        let key = UserDefaults.standard.string(forKey: "licenseKey") ?? ""

        let result = await client.validateSmart(
            keyOrCode: key,
            hardwareId: hwid,
            productName: "MyApp"
        )

        isLicensed = result.isValid
        features = result.features
    }
}
```

## Offline Licensing

For air-gapped environments, validate licenses locally without any server connection:

```swift
let client = try ExisOneClient(options: ExisOneClientOptions(
    baseURL: "https://www.exisone.com",
    accessToken: "your-token",
    offlinePublicKey: """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A...
    -----END PUBLIC KEY-----
    """
))

// Smart validation - auto-detects online vs offline keys
let result = await client.validateSmart(
    keyOrCode: licenseKeyOrOfflineCode,
    hardwareId: hwid,
    productName: "MyApp"
)

if result.isValid {
    print("Mode: \(result.wasOffline ? "offline" : "online")")
    print("Features: \(result.features)")
}
```

Generate offline codes from the [License Keys](https://www.exisone.com/license.html) page using the customer's Hardware ID. Obtain your public key from the [Crypto Keys](https://www.exisone.com/tenant-keys.html) page.

## API Overview

| Method | Description |
|--------|-------------|
| `ExisOneHardwareId.generate()` | Hardware fingerprint (64-char hex) |
| `client.activate(...)` | Activate a license on this machine |
| `client.validate(...)` | Validate a license online |
| `client.deactivate(...)` | Release a license from this machine |
| `client.validateOffline(...)` | Validate offline (no server needed) |
| `client.validateSmart(...)` | Auto-detect online/offline with fallback |
| `client.deactivateSmart(...)` | Deactivate with opportunistic server sync |
| `client.generateActivationKey(...)` | Generate a key (admin) |
| `client.getLicensedFeatures(...)` | Get feature list for a key |
| `client.sendSupportTicket(...)` | Submit a support ticket |

## Error Handling

```swift
do {
    let result = try await client.validate(
        hardwareId: hwid,
        productName: "MyApp",
        activationKey: key
    )
} catch let error as ExisOneError {
    switch error {
    case .httpError(let code, let message):
        print("Server error \(code): \(message)")
    case .networkError(let message):
        print("Network issue: \(message)")
    case .insecureBaseURL:
        print("HTTPS required")
    case .hostNotAllowed(let host):
        print("Host \(host) not in allow list")
    default:
        print(error.localizedDescription)
    }
}
```

## Version Enforcement

Ensure customers run a minimum app version:

```swift
let result = try await client.validate(
    hardwareId: hwid,
    productName: "MyApp",
    activationKey: key,
    version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
)

if result.status == "version_outdated" {
    print("Update required: minimum version is \(result.minimumRequiredVersion ?? "unknown")")
}
```

Configure the minimum version in your [ExisOne dashboard](https://www.exisone.com) under Product settings.

## Documentation

- [Swift SDK Documentation](https://www.exisone.com/docs-sdk-swift.html)
- [REST API Documentation](https://www.exisone.com/docs.html)
- [.NET SDK](https://www.exisone.com/docs-sdk.html) | [Python SDK](https://www.exisone.com/docs-sdk-python.html) | [Node.js SDK](https://www.exisone.com/docs-sdk-node.html)

## License

Copyright (c) Exis, LLC. All rights reserved.
