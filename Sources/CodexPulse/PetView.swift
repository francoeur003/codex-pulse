import AppKit
import SwiftUI

struct PetView: View {
    @ObservedObject var model: PulseModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var breathing = false
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if model.showDetails {
                detailsCard
                    .offset(y: -252)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            pet
                .offset(y: model.pose == .recover ? -18 : (breathing ? -2 : 2))
                .scaleEffect(model.pose == .combo ? 0.96 : 1)
                .rotationEffect(.degrees(model.pose == .hit ? -1.5 : 0))
                .animation(motion(.spring(response: 0.24, dampingFraction: 0.58)), value: model.pose)
                .onTapGesture {
                    withAnimation(motion(.easeOut(duration: 0.22))) {
                        model.showDetails.toggle()
                    }
                }

            quotaPill
                .offset(y: -8)

            ForEach(Array(model.floaters.enumerated()), id: \.element.id) { index, floater in
                FloaterView(floater: floater, lane: index) {
                    model.removeFloater(floater.id)
                }
                .offset(x: CGFloat((index % 3) - 1) * 42, y: -130)
            }
        }
        .frame(width: 420, height: 520)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.trailing, 14)
                .transition(.opacity)
                .help("退出 Codex Pulse")
            }
        }
        .onAppear {
            model.reduceMotion = systemReduceMotion
            guard !systemReduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private var pet: some View {
        Image(nsImage: PetAssets.image(named: model.pose.assetName))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 250, height: 250)
            .shadow(color: PulseTokens.accent.opacity(0.14), radius: 12, y: 6)
            .accessibilityLabel(accessibilityPoseLabel)
    }

    private var quotaPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.isConnected ? PulseTokens.success : PulseTokens.warning)
                .frame(width: 8, height: 8)
                .shadow(color: (model.isConnected ? PulseTokens.success : PulseTokens.warning).opacity(0.45), radius: 4)
            Text("本周剩余")
                .foregroundStyle(PulseTokens.muted)
            Text("\(model.remainingPercent)%")
                .fontWeight(.bold)
                .foregroundStyle(PulseTokens.ink)
            Divider().frame(height: 14)
            Text("今日 \(model.todayLabel)")
                .foregroundStyle(PulseTokens.muted)
                .lineLimit(1)
            Divider().frame(height: 14)
            Text(model.resetLabel)
                .foregroundStyle(PulseTokens.muted)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(PulseTokens.border.opacity(0.9), lineWidth: 1))
        .shadow(color: .black.opacity(0.13), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Codex Pulse", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(model.plan)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(PulseTokens.accent.opacity(0.12), in: Capsule())
                    .foregroundStyle(PulseTokens.accent)
            }
            metricRow(title: "Codex 周额度", value: "已用 \(model.usedPercent)%", progress: Double(model.usedPercent) / 100)
            if let reserveUsed = model.reserveUsedPercent {
                metricRow(title: "Reserve 模型", value: "剩余 \(100 - reserveUsed)%", progress: Double(reserveUsed) / 100)
            }
            HStack {
                Label(model.connection, systemImage: model.isConnected ? "wave.3.right" : "exclamationmark.triangle")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(PulseTokens.muted)
        }
        .padding(14)
        .frame(width: 364)
        .background(PulseTokens.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PulseTokens.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
    }

    private func metricRow(title: String, value: String, progress: Double) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(value).monospacedDigit()
            }
            .font(.system(size: 11, weight: .medium))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.06))
                    Capsule().fill(PulseTokens.accent).frame(width: max(4, proxy.size.width * min(1, max(0, progress))))
                }
            }
            .frame(height: 5)
        }
    }

    private var accessibilityPoseLabel: String {
        switch model.pose {
        case .idle: "Codex 小助手正在待机"
        case .hit: "Codex 小助手检测到一轮 Token 消耗"
        case .combo: "Codex 小助手检测到连续 Token 消耗"
        case .recover: "Codex 小助手检测到额度恢复"
        }
    }

    private func motion(_ animation: Animation) -> Animation {
        (systemReduceMotion || model.reduceMotion) ? .linear(duration: 0.01) : animation
    }
}

private enum PetAssets {
    static func image(named name: String) -> NSImage {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        let executableFolder = URL(fileURLWithPath: CommandLine.arguments[0])
            .standardizedFileURL
            .deletingLastPathComponent()
        let fallbackURLs = [
            executableFolder.appendingPathComponent("../Resources/\(name).png").standardizedFileURL,
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sources/CodexPulse/Resources/\(name).png")
        ]
        for url in fallbackURLs {
            if let image = NSImage(contentsOf: url) { return image }
        }
        return NSImage(size: NSSize(width: 1, height: 1))
    }
}

private struct FloaterView: View {
    let floater: TokenFloater
    let lane: Int
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fading = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: floater.strong ? "bolt.fill" : "cube.fill")
            Text(floater.text)
                .monospacedDigit()
        }
        .font(.system(size: floater.strong ? 17 : 14, weight: .heavy, design: .rounded))
        .foregroundStyle(floater.strong ? PulseTokens.warning : PulseTokens.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke((floater.strong ? PulseTokens.warning : PulseTokens.accent).opacity(0.32)))
        .offset(y: fading ? -60 : 0)
        .scaleEffect(fading ? 1.02 : 1)
        .opacity(fading ? 0 : 1)
        .onAppear {
            let holdDuration = reduceMotion ? 2.2 : 1.9
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                withAnimation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.9)) {
                    fading = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.08 : 0.92)) {
                    onFinish()
                }
            }
        }
        .accessibilityLabel("本轮消耗 \(floater.text)")
    }
}
