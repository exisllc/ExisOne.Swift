import Foundation
import CryptoKit

#if canImport(IOKit)
import IOKit
#endif

/// Generates a stable hardware fingerprint for the current machine.
///
/// Uses platform-specific identifiers (Hardware UUID, MAC addresses, CPU info)
/// hashed with SHA-256 to produce a consistent 64-character hex string.
///
/// The algorithm matches the ExisOne Python and Node.js SDKs on macOS.
public enum ExisOneHardwareId {

    /// Salt prepended before hashing (must match all ExisOne SDKs).
    private static let salt = "ExisOneHardwareSalt_v1"

    /// Generate a hardware fingerprint for this machine.
    ///
    /// - Returns: 64-character uppercase hex string (SHA-256 hash).
    public static func generate() -> String {
        var components: [String] = []

        // Platform-specific identifiers
        components.append(contentsOf: platformIdentifiers())

        // MAC addresses (all platforms)
        components.append(contentsOf: macAddresses())

        // Generic system info
        components.append(architecture())
        components.append(String(ProcessInfo.processInfo.activeProcessorCount))
        components.append(ProcessInfo.processInfo.hostName)
        components.append(osVersionString())

        // Combine and hash
        let combined = components.joined()
        let salted = salt + combined
        let data = Data(salted.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02X", $0) }.joined()
    }

    // MARK: - Platform identifiers

    private static func platformIdentifiers() -> [String] {
        var identifiers: [String] = []

        #if os(macOS)
        // macOS: Hardware UUID via IOKit (same value as system_profiler Hardware UUID)
        if let uuid = hardwareUUID() {
            identifiers.append(uuid)
        }
        #elseif os(Linux)
        // Linux: machine-id files
        let machineIdPaths = [
            "/etc/machine-id",
            "/var/lib/dbus/machine-id",
            "/sys/class/dmi/id/product_uuid"
        ]
        for path in machineIdPaths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
               !content.isEmpty {
                identifiers.append(content)
            }
        }

        // /proc/cpuinfo
        if let content = try? String(contentsOfFile: "/proc/cpuinfo", encoding: .utf8) {
            identifiers.append(content)
        }
        #endif

        return identifiers
    }

    #if os(macOS)
    /// Get the Hardware UUID via IOKit (equivalent to system_profiler Hardware UUID).
    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        let key = kIOPlatformUUIDKey as CFString
        guard let cfValue = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0) else {
            return nil
        }
        return cfValue.takeRetainedValue() as? String
    }
    #endif

    // MARK: - MAC addresses

    private static func macAddresses() -> [String] {
        var macs: [String] = []

        #if canImport(Darwin)
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return macs }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let family = ptr.pointee.ifa_addr.pointee.sa_family
            let flags = Int32(ptr.pointee.ifa_flags)

            // AF_LINK = link-layer address (contains MAC)
            if family == UInt8(AF_LINK) && (flags & IFF_LOOPBACK) == 0 {
                let sdl = ptr.pointee.ifa_addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                let addrLen = Int(sdl.sdl_alen)
                if addrLen == 6 {
                    let macBytes = withUnsafePointer(to: sdl.sdl_data) { dataPtr in
                        dataPtr.withMemoryRebound(to: UInt8.self, capacity: Int(sdl.sdl_nlen) + addrLen) { ptr in
                            (0..<addrLen).map { ptr[Int(sdl.sdl_nlen) + $0] }
                        }
                    }
                    let mac = macBytes.map { String(format: "%02X", $0) }.joined()
                    if mac != "000000000000" && !macs.contains(mac) {
                        macs.append(mac)
                    }
                }
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        #endif

        macs.sort()
        return macs
    }

    // MARK: - System info

    private static func architecture() -> String {
        #if arch(arm64) || arch(x86_64)
        return "x64"
        #else
        return "x86"
        #endif
    }

    private static func osVersionString() -> String {
        let info = ProcessInfo.processInfo
        let ver = info.operatingSystemVersion
        let arch: String
        #if arch(arm64)
        arch = "arm64"
        #elseif arch(x86_64)
        arch = "x86_64"
        #else
        arch = "unknown"
        #endif

        #if os(macOS)
        return "macOS-\(ver.majorVersion).\(ver.minorVersion).\(ver.patchVersion)-\(arch)-arm-64bit"
        #elseif os(iOS)
        return "iOS-\(ver.majorVersion).\(ver.minorVersion).\(ver.patchVersion)"
        #else
        return "unknown-\(ver.majorVersion).\(ver.minorVersion).\(ver.patchVersion)"
        #endif
    }
}
