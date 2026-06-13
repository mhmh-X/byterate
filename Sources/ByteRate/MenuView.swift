import SwiftUI

/// 下拉面板：两家额度同屏展示。
struct MenuView: View {
    static let panelWidth: CGFloat = 300

    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if Settings.showClaude {
                ProviderSection(title: "Claude", icon: Image(nsImage: Icons.claude(size: 16)), iconIsTemplate: false, state: state.claude, note: state.claudeNote)
            }
            if Settings.showClaude && Settings.showCodex {
                Divider()
            }
            if Settings.showCodex {
                ProviderSection(title: "Codex", icon: Image(nsImage: Icons.openAI(size: 16)), iconIsTemplate: true, state: state.codex, note: state.codexNote)
            }
            if let t = state.lastUpdated {
                Divider()
                HStack {
                    Text("\(L.t("更新于", "Updated")) \(t, format: .dateTime.hour().minute())")
                    if state.refreshing { Text(L.t("刷新中…", "refreshing…")) }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: Self.panelWidth, alignment: .leading)
    }
}

private struct ProviderSection: View {
    let title: String
    let icon: Image
    let iconIsTemplate: Bool
    let state: ProviderState
    let note: BiText?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if iconIsTemplate {
                    icon.renderingMode(.template).foregroundStyle(.primary)
                } else {
                    icon
                }
                Text(title).font(.headline)
                if case .ok(let u) = state, let plan = u.plan {
                    Text(plan.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                if case .ok(let u) = state, let expiry = u.planExpiresAt {
                    Text(L.t("订阅 \(expiry.expiryDescription) 到期", "Plan expires \(expiry.expiryDescription)"))
                        .font(.caption2)
                        .foregroundStyle(expiry.timeIntervalSinceNow < 3 * 86400 ? .orange : .secondary)
                }
            }
            switch state {
            case .loading:
                Text(L.t("加载中…", "Loading…")).font(.caption).foregroundStyle(.secondary)
            case .error(let msg):
                Text(msg.text).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            case .ok(let usage):
                if let h = usage.hourly { UsageRow(label: L.t("5 小时", "5-hour"), usage: h) }
                if let w = usage.weekly { UsageRow(label: L.t("每周", "Weekly"), usage: w) }
                if usage.hourly == nil && usage.weekly == nil {
                    Text(L.t("没有返回额度数据", "No quota data returned")).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let note {
                Text(L.t("刷新失败：\(note.text)，显示的是上次数据，稍后自动重试",
                         "Refresh failed: \(note.text) — showing last data, will retry"))
                    .font(.caption2).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct UsageRow: View {
    let label: String
    let usage: WindowUsage

    private var barColor: Color {
        switch usage.remainingPercent {
        case ..<15: return .red
        case ..<40: return .orange
        default: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(usage.remainingPercent.rounded()))%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(barColor)
            }
            BurnBar(remaining: usage.remainingPercent / 100, color: barColor)
                .frame(height: 5)
            if let r = usage.resetsAt {
                let duration = Text(r.remainingDescription)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                if L.isZH {
                    (duration
                     + Text(" 后重置（\(r.resetDescription)）")
                        .font(.caption2)
                        .foregroundColor(.secondary))
                } else {
                    (Text("Resets in ")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                     + duration
                     + Text(" (\(r.resetDescription))")
                        .font(.caption2)
                        .foregroundColor(.secondary))
                }
            }
        }
    }
}

/// 从右往左的额度条：右侧彩色 = 剩余额度，左侧淡灰 = 已消耗。
private struct BurnBar: View {
    let remaining: Double   // 0–1
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.65), color],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: remaining <= 0 ? 0 : max(geo.size.height, geo.size.width * remaining))
            }
        }
    }
}
