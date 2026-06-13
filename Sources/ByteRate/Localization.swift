import Foundation

/// 极简双语支持：默认跟随系统语言，可在菜单里手动切换并持久化。
enum L {
    private static let key = "appLanguage"

    static var code: String {
        UserDefaults.standard.string(forKey: key)
            ?? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh" : "en")
    }

    static var isZH: Bool { code == "zh" }

    static func set(_ code: String) {
        UserDefaults.standard.set(code, forKey: key)
    }

    static func t(_ zh: String, _ en: String) -> String { isZH ? zh : en }
}
