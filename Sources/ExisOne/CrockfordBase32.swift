import Foundation

/// Crockford Base32 decoder.
///
/// Alphabet: `0123456789ABCDEFGHJKMNPQRSTVWXYZ` (excludes I, L, O, U to avoid
/// confusion with 1, l, 0, V). Used for encoding offline activation codes.
enum CrockfordBase32 {

    private static let alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

    /// Build reverse lookup table at first use.
    private static let lookup: [Character: UInt8] = {
        var map = [Character: UInt8]()
        for (index, char) in alphabet.enumerated() {
            map[char] = UInt8(index)
        }
        return map
    }()

    /// Decode a Crockford Base32 encoded string to raw bytes.
    ///
    /// Invalid characters (including dashes and spaces used as separators) are
    /// silently skipped.
    ///
    /// - Parameter encoded: The Base32 string to decode.
    /// - Returns: Decoded bytes.
    static func decode(_ encoded: String) -> Data {
        guard !encoded.isEmpty else { return Data() }

        var result = [UInt8]()
        var buffer: UInt32 = 0
        var bitsLeft: Int = 0

        for char in encoded.uppercased() {
            guard let value = lookup[char] else { continue }
            buffer = (buffer << 5) | UInt32(value)
            bitsLeft += 5

            if bitsLeft >= 8 {
                bitsLeft -= 8
                result.append(UInt8((buffer >> bitsLeft) & 0xFF))
            }
        }

        return Data(result)
    }
}
