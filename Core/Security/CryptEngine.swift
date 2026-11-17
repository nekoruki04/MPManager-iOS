import Foundation
import CryptoKit
import CommonCrypto

public final class CryptEngine: Sendable {
    public static let shared = CryptEngine()

    public init() {}

    public func derive_key(password: String, salt: Data) throws -> SymmetricKey {
        let password_data = password.data(using: .utf8) ?? Data()
        var derived_key_data = Data(repeating: 0, count: 32)

        let status = derived_key_data.withUnsafeMutableBytes { derived_bytes in
            salt.withUnsafeBytes { salt_bytes in
                password_data.withUnsafeBytes { pass_bytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pass_bytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password_data.count,
                        salt_bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        100000,
                        derived_bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        if status != kCCSuccess {
            throw NSError(domain: "CryptEngine", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Key derivation failed"])
        }
        return SymmetricKey(data: derived_key_data)
    }

    public func encrypt_file(at source_path: String, to destination_path: String, password: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: source_path))
        var salt = Data(repeating: 0, count: 16)
        let salt_result = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard salt_result == errSecSuccess else {
            throw NSError(domain: "CryptEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate salt"])
        }

        let key = try derive_key(password: password, salt: salt)
        let sealed_box = try AES.GCM.seal(data, using: key)
        guard let combined = sealed_box.combined else {
            throw NSError(domain: "CryptEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "AES-GCM encryption failed"])
        }

        var payload = Data()
        payload.append("MPENC1".data(using: .utf8)!)
        payload.append(salt)
        payload.append(combined)
        try payload.write(to: URL(fileURLWithPath: destination_path), options: .atomic)
    }

    public func decrypt_file(at source_path: String, to destination_path: String, password: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: source_path))
        guard data.count >= 6 + 16 + 28 else {
            throw NSError(domain: "CryptEngine", code: 3, userInfo: [NSLocalizedDescriptionKey: "Corrupted or invalid encrypted file"])
        }

        let magic = data.subdata(in: 0..<6)
        guard let magic_str = String(data: magic, encoding: .utf8), magic_str == "MPENC1" else {
            throw NSError(domain: "CryptEngine", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unrecognized encryption header"])
        }

        let salt = data.subdata(in: 6..<22)
        let ciphertext = data.subdata(in: 22..<data.count)

        let key = try derive_key(password: password, salt: salt)
        let sealed_box = try AES.GCM.SealedBox(combined: ciphertext)
        let decrypted = try AES.GCM.open(sealed_box, using: key)

        try decrypted.write(to: URL(fileURLWithPath: destination_path), options: .atomic)
    }
}
