import Foundation
import UserNotifications

/// 低额度系统通知。
/// 去重：每个（服务商 × 窗口 × 阈值 × 重置周期）只通知一次，窗口重置后自动重新武装；
/// 订阅临期每天最多一次。已发记录持久化，重启不重复打扰。
@MainActor
enum Notifier {
    private static let sentKey = "sentNotifications"
    private static var authRequested = false

    static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorizationIfNeeded() {
        guard available, !authRequested, !Settings.thresholds.isEmpty else { return }
        authRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func check(provider: String, state: ProviderState) {
        // 「关闭」= 关掉所有通知，包括订阅到期提醒
        let thresholds = Settings.thresholds
        guard available, !thresholds.isEmpty, case .ok(let usage) = state else { return }
        var sent = loadSent()

        do {
            let windows: [(String, String, WindowUsage?)] = [
                ("5 小时", "5-hour", usage.hourly),
                ("周", "weekly", usage.weekly),
            ]
            for (zh, en, window) in windows {
                guard let w = window else { continue }
                // 没有重置时间时按自然日兜底，保证至少每天能重新提醒
                let cycle = w.resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? dayString(Date())
                // 只对跌破的最低阈值通知（剩 4% 时不必同时发 20%/10%/5% 三条）
                guard let t = thresholds.filter({ w.remainingPercent < Double($0) }).min() else { continue }
                let key = "\(provider)|\(en)|\(t)|\(cycle)"
                guard !sent.contains(key) else { continue }
                sent.append(key)
                let reset = w.resetsAt.map {
                    L.t("，\($0.resetDescription)重置", " — resets \($0.resetDescription)")
                } ?? ""
                send(
                    provider: provider,
                    title: L.t("\(providerLabel(provider)) 额度告警", "\(providerLabel(provider)) quota alert"),
                    body: L.t("\(zh)额度仅剩 \(Int(w.remainingPercent.rounded()))%（低于 \(t)%）\(reset)",
                              "\(en.capitalized) window down to \(Int(w.remainingPercent.rounded()))% (below \(t)%)\(reset)")
                )
            }
        }

        if let expiry = usage.planExpiresAt,
           expiry.timeIntervalSinceNow > 0, expiry.timeIntervalSinceNow < 3 * 86400 {
            let key = "expiry|\(provider)|\(dayString(Date()))"
            if !sent.contains(key) {
                sent.append(key)
                send(
                    provider: provider,
                    title: L.t("\(providerLabel(provider)) 订阅即将到期", "\(providerLabel(provider)) plan expiring"),
                    body: L.t("订阅将于 \(expiry.expiryDescription)（\(expiry.remainingDescription)后）到期",
                              "Plan expires \(expiry.expiryDescription) (in \(expiry.remainingDescription))")
                )
            }
        }

        saveSent(sent)
    }

    private static func send(provider: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    private static func providerLabel(_ provider: String) -> String {
        provider == "Claude" ? "✳︎ Claude" : "◎ Codex"
    }

    private static func dayString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private static func loadSent() -> [String] {
        UserDefaults.standard.stringArray(forKey: sentKey) ?? []
    }

    private static func saveSent(_ sent: [String]) {
        // 只留最近 200 条，老的周期早已过去
        UserDefaults.standard.set(Array(sent.suffix(200)), forKey: sentKey)
    }
}
