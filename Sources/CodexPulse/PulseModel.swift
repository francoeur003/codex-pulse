import Foundation
import SwiftUI

enum PetPose: String {
    case idle
    case hit
    case combo
    case recover

    var assetName: String {
        switch self {
        case .idle: "pet-idle"
        case .hit: "pet-hit"
        case .combo: "pet-combo"
        case .recover: "pet-recover"
        }
    }
}

struct TokenFloater: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let strong: Bool
}

@MainActor
final class PulseModel: ObservableObject {
    @Published var usedPercent = 0
    @Published var reserveUsedPercent: Int?
    @Published var resetAt: Date?
    @Published var todayTokens: Int64?
    @Published var lifetimeTokens: Int64?
    @Published var plan = "—"
    @Published var connection = "正在连接 Codex"
    @Published var isConnected = false
    @Published var pose: PetPose = .idle
    @Published var floaters: [TokenFloater] = []
    @Published var showDetails = false
    @Published var reduceMotion = false

    private var poseTask: Task<Void, Never>?
    private var recentEvents: [Date] = []
    private var lastUsedPercent: Int?

    var remainingPercent: Int { max(0, 100 - usedPercent) }

    var resetLabel: String {
        guard let resetAt else { return "等待额度数据" }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return relative.localizedString(for: resetAt, relativeTo: Date()) + "重置"
    }

    var todayLabel: String {
        guard let todayTokens else { return "暂不可用" }
        return Self.formatTokens(todayTokens)
    }

    func applyRateLimit(used: Int, resetEpoch: Int64?, plan: String?, reserveUsed: Int?) {
        if let previous = lastUsedPercent {
            if used > previous {
                react(tokens: nil, percentCrossed: used - previous)
            } else if used < previous {
                showPose(.recover, duration: 1.5)
            }
        }
        lastUsedPercent = used
        usedPercent = min(100, max(0, used))
        if let reserveUsed { reserveUsedPercent = reserveUsed }
        if let resetEpoch { resetAt = Date(timeIntervalSince1970: TimeInterval(resetEpoch)) }
        if let plan { self.plan = plan.uppercased() }
        connection = "实时同步"
        isConnected = true
    }

    func applyUsage(today: Int64?, lifetime: Int64?) {
        if let today { todayTokens = today }
        if let lifetime { lifetimeTokens = lifetime }
    }

    func showConnectionError(_ message: String) {
        connection = message
        isConnected = false
    }

    func react(tokens: Int64?, percentCrossed: Int = 0) {
        let now = Date()
        recentEvents = recentEvents.filter { now.timeIntervalSince($0) < 2.2 }
        recentEvents.append(now)

        let isCombo = recentEvents.count >= 3 || (tokens ?? 0) >= 180_000
        if let tokens, tokens > 0 {
            addFloater("−" + Self.formatTokens(tokens), strong: isCombo)
        }
        if percentCrossed > 0 {
            addFloater("−\(percentCrossed)%", strong: true)
        }
        showPose(isCombo ? .combo : .hit, duration: isCombo ? 1.15 : 0.78)
    }

    func removeFloater(_ id: UUID) {
        floaters.removeAll { $0.id == id }
    }

    private func addFloater(_ text: String, strong: Bool) {
        let item = TokenFloater(text: text, strong: strong)
        floaters.append(item)
        Task {
            try? await Task.sleep(for: .milliseconds(3200))
            removeFloater(item.id)
        }
    }

    private func showPose(_ newPose: PetPose, duration: Double) {
        poseTask?.cancel()
        pose = newPose
        poseTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            pose = .idle
        }
    }

    static func formatTokens(_ value: Int64) -> String {
        let number = Double(value)
        if value >= 1_000_000_000 { return String(format: "%.2fB tok", number / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM tok", number / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK tok", number / 1_000) }
        return "\(value) tok"
    }
}
