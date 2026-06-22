import Foundation

/// 从 Claude Code 的 OAuth 凭据获取 Claude 订阅额度。
/// 凭据来源：macOS 钥匙串 "Claude Code-credentials"（备选 ~/.claude/.credentials.json）。
/// 额度接口：GET https://api.anthropic.com/api/oauth/usage
struct ClaudeProvider: UsageProvider {
    let name = "Claude"

    private static let keychainService = "Claude Code-credentials"
    private static let usageURL = "https://api.anthropic.com/api/oauth/usage"

    static func hasLocalCredentials() -> Bool {
        if Keychain.exists(service: keychainService) { return true }
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        guard let data = try? Data(contentsOf: path) else { return false }
        let root = HTTP.json(data)
        return root["claudeAiOauth"] is [String: Any]
    }

    func fetch() async -> ProviderState {
        do {
            // 纯只读：只读取 Claude Code 现有的 token，绝不刷新、绝不写回钥匙串。
            // 写回会扰动那条凭据的访问控制（ACL），导致 Claude Code 自己访问时反复弹密码框，
            // 所以这里把写操作彻底去掉，token 续期完全交给 Claude Code 自己。
            let oauth = try Self.loadCredentials()
            guard let token = oauth["accessToken"] as? String else {
                throw UsageError.message("凭据里没有 accessToken", "No accessToken in credentials")
            }
            let (status, data) = try await Self.callUsage(token: token)
            if status == 401 {
                throw UsageError.message("Claude 凭据已过期，在 Claude Code 里用一次即可刷新",
                                        "Claude credential expired — use Claude Code once to refresh it")
            }
            if status == 429 {
                throw UsageError.message("请求过于频繁被临时限流（429）", "Temporarily rate-limited (429)")
            }
            guard status == 200 else {
                throw UsageError.message("额度接口返回 \(status)", "Usage API returned \(status)")
            }
            let plan = oauth["subscriptionType"] as? String
            let usage = Self.parseUsage(HTTP.json(data), plan: plan)
            guard usage.hourly != nil || usage.weekly != nil else {
                throw UsageError.message("接口返回结构无法识别，可能已变更",
                                         "Unrecognized usage API response — schema may have changed")
            }
            return .ok(usage)
        } catch let e as UsageError {
            return .error(e.bi)
        } catch {
            let raw = error.localizedDescription
            return .error(BiText(zh: raw, en: raw))
        }
    }

    // MARK: - 凭据（只读）

    /// 读取 Claude Code 的 OAuth 字典。钥匙串优先，回退 ~/.claude/.credentials.json。只读，不写回。
    private static func loadCredentials() throws -> [String: Any] {
        let data: Data
        if let (d, _) = try? Keychain.read(service: keychainService) {
            data = d
        } else {
            let path = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/.credentials.json")
            guard let d = try? Data(contentsOf: path) else {
                throw UsageError.message("找不到 Claude Code 凭据，请先在 Claude Code 里登录", "Claude Code credentials not found — sign in to Claude Code first")
            }
            data = d
        }
        guard let oauth = HTTP.json(data)["claudeAiOauth"] as? [String: Any] else {
            throw UsageError.message("凭据格式不正确", "Malformed credentials")
        }
        return oauth
    }

    private static func callUsage(token: String) async throws -> (Int, Data) {
        try await HTTP.request(usageURL, headers: [
            "Authorization": "Bearer \(token)",
            "anthropic-beta": "oauth-2025-04-20",
        ])
    }

    // MARK: - 解析

    private static func parseUsage(_ json: [String: Any], plan: String?) -> ProviderUsage {
        ProviderUsage(
            hourly: parseWindow(json["five_hour"]),
            weekly: parseWindow(json["seven_day"]),
            plan: plan
        )
    }

    private static func parseWindow(_ value: Any?) -> WindowUsage? {
        guard let dict = value as? [String: Any] else { return nil }
        // 百分比缺失/非法时宁可不显示该窗口，也不能默认 0 已用谎报"剩 100%"
        guard let raw = (dict["utilization"] as? Double) ?? (dict["used_percent"] as? Double),
              raw.isFinite else { return nil }
        let used = min(max(raw, 0), 100)
        var resets: Date?
        if let s = dict["resets_at"] as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            resets = iso.date(from: s)
            if resets == nil {
                iso.formatOptions = [.withInternetDateTime]
                resets = iso.date(from: s)
            }
        } else if let t = dict["resets_at"] as? Double {
            resets = Date(timeIntervalSince1970: t)
        }
        return WindowUsage(usedPercent: used, resetsAt: resets)
    }
}
