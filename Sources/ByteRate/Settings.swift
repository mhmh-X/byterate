import Foundation

/// 用户偏好（UserDefaults 持久化）。
enum Settings {
    private static let thresholdsKey = "notifyThresholds"
    private static let menuBarModeKey = "menuBarMode"
    private static let legacyPreferenceDomains = [
        "com.mhh.byterate",
        "com.mhh.burnrate"
    ]

    /// 可选的通知阈值（剩余百分比），可多选。
    static let allThresholds = [20, 10, 5]

    static var thresholds: Set<Int> {
        get {
            if let arr = UserDefaults.standard.array(forKey: thresholdsKey) as? [Int] {
                return Set(arr)
            }
            return []   // 默认关闭通知
        }
        set { UserDefaults.standard.set(Array(newValue).sorted(by: >), forKey: thresholdsKey) }
    }

    enum MenuBarMode: String, CaseIterable {
        case fiveHour   // 5 小时窗
        case weekly     // 周窗
        case lowest     // 两窗最低值
        case iconOnly   // 纯图标
    }

    static var menuBarMode: MenuBarMode {
        get { MenuBarMode(rawValue: UserDefaults.standard.string(forKey: menuBarModeKey) ?? "") ?? .fiveHour }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: menuBarModeKey) }
    }

    /// 服务商开关（只用一家时关掉另一家，不再请求也不再展示）。
    private static let showClaudeKey = "showClaude"
    private static let showCodexKey = "showCodex"

    static var showClaude: Bool {
        get {
            if let value = UserDefaults.standard.object(forKey: showClaudeKey) as? Bool {
                return value
            }
            return defaultProviders.showClaude
        }
        set { UserDefaults.standard.set(newValue, forKey: showClaudeKey) }
    }

    static var showCodex: Bool {
        get {
            if let value = UserDefaults.standard.object(forKey: showCodexKey) as? Bool {
                return value
            }
            return defaultProviders.showCodex
        }
        set { UserDefaults.standard.set(newValue, forKey: showCodexKey) }
    }

    /// 首次启动时把"按本机凭据判断"的默认值固化写入，之后只由菜单修改，
    /// 避免未手动设置的一侧随凭据文件出现/消失而漂移。
    static func materializeDefaults() {
        migrateLegacyDefaultsIfNeeded()

        let defaults = UserDefaults.standard
        let claudeMissing = defaults.object(forKey: showClaudeKey) == nil
        let codexMissing = defaults.object(forKey: showCodexKey) == nil
        guard claudeMissing || codexMissing else { return }
        let d = defaultProviders
        // 只补缺失的 key，不覆盖用户已设置过的另一个
        if claudeMissing { defaults.set(d.showClaude, forKey: showClaudeKey) }
        if codexMissing { defaults.set(d.showCodex, forKey: showCodexKey) }
    }

    private static var defaultProviders: (showClaude: Bool, showCodex: Bool) {
        let hasClaude = ClaudeProvider.hasLocalCredentials()
        let hasCodex = CodexProvider.hasLocalCredentials()
        if hasClaude || hasCodex {
            return (hasClaude, hasCodex)
        }
        // 两边都没有本机登录痕迹时仍展示两项，方便用户看到登录指引。
        return (true, true)
    }

    private static func migrateLegacyDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let keys = [thresholdsKey, menuBarModeKey, showClaudeKey, showCodexKey]
        guard keys.contains(where: { defaults.object(forKey: $0) == nil }) else { return }

        for domain in legacyPreferenceDomains {
            guard let legacy = UserDefaults(suiteName: domain) else { continue }
            for key in keys where defaults.object(forKey: key) == nil {
                if let value = legacy.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
        }
    }
}
