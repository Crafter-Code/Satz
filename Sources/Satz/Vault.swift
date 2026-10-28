import Foundation
import CryptoKit
import Security
import SatzCore

enum LocalPaths {
    static let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Satz", isDirectory: true)
    static func model(_ id: String) -> URL {
        root.appendingPathComponent(id == "fast" ? "Models/Qwen3-1.7B-Q8_0.gguf" : "Models/Qwen3-4B-Q4_K_M.gguf")
    }
    static let vault = root.appendingPathComponent("personalization.sealed")
    static func prepare() throws {
        for folder in [root, root.appendingPathComponent("Models"), root.appendingPathComponent("Backups")] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
    }
}

final class Vault {
    private let key: SymmetricKey
    init() throws {
        try LocalPaths.prepare()
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "org.satz.local.vault", kSecAttrAccount as String: "encryption-key"]
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        if status == errSecSuccess, let bytes = item as? Data, bytes.count == 32 {
            key = SymmetricKey(data: bytes)
        } else if status == errSecItemNotFound && !FileManager.default.fileExists(atPath: LocalPaths.vault.path) {
            let created = SymmetricKey(size: .bits256)
            var save = query
            save[kSecValueData as String] = created.withUnsafeBytes { Data($0) }
            save[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let result = SecItemAdd(save as CFDictionary, nil)
            guard result == errSecSuccess else { throw Self.failure("Cannot create the local encryption key (\(result)).") }
            key = created
        } else {
            throw Self.failure("The local encryption key is unavailable (\(status)). Existing data has been preserved. Unlock Keychain and restart Satz.")
        }
    }

    func load() throws -> LocalData {
        guard FileManager.default.fileExists(atPath: LocalPaths.vault.path) else { return LocalData() }
        let bytes = try Data(contentsOf: LocalPaths.vault)
        let opened = try AES.GCM.open(AES.GCM.SealedBox(combined: bytes), using: key)
        return try JSONDecoder().decode(LocalData.self, from: opened)
    }

    func save(_ data: LocalData) throws {
        let sealed = try AES.GCM.seal(JSONEncoder().encode(data), using: key)
        guard let bytes = sealed.combined else { throw Self.failure("Unable to encrypt local data.") }
        try bytes.write(to: LocalPaths.vault, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: LocalPaths.vault.path)
    }

    private static func failure(_ message: String) -> NSError { NSError(domain: "Satz", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
