import Foundation
import Security
import LocalAuthentication

enum Keychain {
    /// 只检查通用密码项是否存在，不读取 secret，避免默认设置探测阶段弹授权框。
    static func exists(service: String) -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    /// 读取通用密码项的内容和账户名（首次访问会弹出钥匙串授权，选"始终允许"即可）。
    static func read(service: String) throws -> (data: Data, account: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let item = result as? [String: Any],
              let data = item[kSecValueData as String] as? Data else {
            throw UsageError.message("读取钥匙串失败（\(status)）：未登录 Claude Code？", "Keychain read failed (\(status)) — not signed in to Claude Code?")
        }
        return (data, item[kSecAttrAccount as String] as? String)
    }

    /// 更新通用密码项内容（带 account 精确匹配，不存在则新建）。
    static func upsert(service: String, account: String?, data: Data) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let account { query[kSecAttrAccount as String] = account }
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw UsageError.message("写入钥匙串失败（\(addStatus)）", "Keychain add failed (\(addStatus))")
            }
            return
        }
        guard status == errSecSuccess else {
            throw UsageError.message("写回钥匙串失败（\(status)）", "Keychain update failed (\(status))")
        }
    }
}
