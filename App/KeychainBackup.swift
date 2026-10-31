import Foundation
import Security
import SwiftUI
import UniformTypeIdentifiers

/// Keeps a copy of your setup in the iPhone's Keychain.
/// Unlike normal app data, the Keychain usually survives deleting and re-signing the app,
/// as long as you sign with the same certificate and keep the same bundle ID.
enum KeychainBackup {
    private static let service = "com.islandstudio.setup"
    private static let account = "backup"

    private static func base() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func save(_ data: Data) -> Bool {
        SecItemDelete(base() as CFDictionary)
        var item = base()
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func load() -> Data? {
        var query = base()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func loadBackup() -> BackupData? {
        guard let data = load() else { return nil }
        return try? JSONDecoder().decode(BackupData.self, from: data)
    }
}

/// A backup file you can save to the Files app (it lives outside the app, so it always survives).
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
