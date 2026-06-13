import Foundation

/// 轻量更新检查：查 GitHub 最新 release 的 tag 和当前版本比对。
enum UpdateChecker {
    static let releasesURL = "https://github.com/mhmh-X/byterate/releases/latest"
    private static let apiURL = "https://api.github.com/repos/mhmh-X/byterate/releases/latest"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    enum Result {
        case upToDate(String)
        case newVersion(String)
        case failed(String)
    }

    static func check() async -> Result {
        do {
            let (status, data) = try await HTTP.request(apiURL, headers: ["Accept": "application/vnd.github+json"])
            guard status == 200 else {
                return .failed(L.t("检查失败（\(status)）", "Check failed (\(status))"))
            }
            guard let tag = HTTP.json(data)["tag_name"] as? String else {
                return .failed(L.t("响应缺少版本号", "Response missing tag_name"))
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            return isNewer(latest, than: currentVersion) ? .newVersion(latest) : .upToDate(latest)
        } catch {
            return .failed(L.t("网络错误：\(error.localizedDescription)",
                               "Network error: \(error.localizedDescription)"))
        }
    }

    /// 简单语义化版本比较（按 . 分段比数字）。
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
