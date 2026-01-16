import Foundation
import Security

/// Keychain 安全存储辅助类
public final class KeychainHelper {

    public static let shared = KeychainHelper()

    private let service = "com.pgarlic.ptt"

    private init() {}

    // MARK: - 公开 API

    /// 保存字符串到 Keychain
    /// - Parameters:
    ///   - value: 要保存的字符串
    ///   - key: 键名
    /// - Returns: 是否保存成功
    @discardableResult
    public func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, forKey: key)
    }

    /// 从 Keychain 读取字符串
    /// - Parameter key: 键名
    /// - Returns: 存储的字符串，如果不存在返回 nil
    public func get(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 从 Keychain 删除指定键
    /// - Parameter key: 键名
    /// - Returns: 是否删除成功
    @discardableResult
    public func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - 内部实现

    private func save(_ data: Data, forKey key: String) -> Bool {
        // 先删除旧数据
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[KeychainHelper] Failed to save key '\(key)': \(status)")
        }
        return status == errSecSuccess
    }

    private func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
}
