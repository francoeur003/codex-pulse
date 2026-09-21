import Foundation

final class CodexBridge: @unchecked Sendable {
    private weak var model: PulseModel?
    private let queue = DispatchQueue(label: "codex-pulse.bridge")
    private var process: Process?
    private var stdin: FileHandle?
    private var stdoutBuffer = Data()
    private var timer: DispatchSourceTimer?

    init(model: PulseModel) {
        self.model = model
    }

    func start() {
        queue.async { [weak self] in self?.launch() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        process?.terminate()
        process = nil
    }

    private func launch() {
        let task = Process()
        guard let codex = resolveCodexExecutable() else {
            publishError("未找到 Codex CLI")
            return
        }
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        task.executableURL = codex
        task.arguments = ["app-server", "--stdio"]
        task.standardInput = input
        task.standardOutput = output
        task.standardError = errors
        task.environment = ProcessInfo.processInfo.environment
        process = task
        stdin = input.fileHandleForWriting

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { self?.consume(data) }
        }
        task.terminationHandler = { [weak self] _ in
            self?.publishError("Codex 数据连接已断开")
        }

        do {
            try task.run()
            send(id: 1, method: "initialize", params: [
                "clientInfo": ["name": "codex-pulse", "title": "Codex Pulse", "version": "0.1.0"],
                "capabilities": ["experimentalApi": true, "optOutNotificationMethods": []]
            ])
        } catch {
            publishError("Codex 连接启动失败")
        }
    }

    private func consume(_ data: Data) {
        stdoutBuffer.append(data)
        while let newline = stdoutBuffer.firstRange(of: Data([0x0A])) {
            let line = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<newline.lowerBound)
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...newline.lowerBound)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            handle(object)
        }
    }

    private func handle(_ message: [String: Any]) {
        if let id = message["id"] as? Int, id == 1 {
            sendNotification(method: "initialized", params: [:])
            refresh()
            startRefreshTimer()
            return
        }
        if let id = message["id"] as? Int, id == 2,
           let result = message["result"] as? [String: Any] {
            applyRateLimit(result)
            return
        }
        if let id = message["id"] as? Int, id == 3,
           let result = message["result"] as? [String: Any] {
            applyUsage(result)
            return
        }
        if message["method"] as? String == "account/rateLimits/updated",
           let params = message["params"] as? [String: Any] {
            applyRateLimit(params)
        }
    }

    private func applyRateLimit(_ result: [String: Any]) {
        let primarySnapshot = (result["rateLimits"] as? [String: Any]) ?? result
        let primary = primarySnapshot["primary"] as? [String: Any]
        let used = Self.int(primary?["usedPercent"]) ?? 0
        let reset = Self.int64(primary?["resetsAt"])
        let plan = primarySnapshot["planType"] as? String

        var reserveUsed: Int?
        if let buckets = result["rateLimitsByLimitId"] as? [String: Any],
           let reserve = buckets["base_model_inference"] as? [String: Any],
           let reserveWindow = reserve["primary"] as? [String: Any] {
            reserveUsed = Self.int(reserveWindow["usedPercent"])
        }

        Task { @MainActor [weak self] in
            self?.model?.applyRateLimit(used: used, resetEpoch: reset, plan: plan, reserveUsed: reserveUsed)
        }
    }

    private func applyUsage(_ result: [String: Any]) {
        let summary = result["summary"] as? [String: Any]
        let lifetime = Self.int64(summary?["lifetimeTokens"])
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        let today = (result["dailyUsageBuckets"] as? [[String: Any]])?
            .first(where: { ($0["startDate"] as? String) == todayString })
            .flatMap { Self.int64($0["tokens"]) }
        Task { @MainActor [weak self] in
            self?.model?.applyUsage(today: today, lifetime: lifetime)
        }
    }

    private func startRefreshTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 60)
        timer.setEventHandler { [weak self] in self?.refresh() }
        timer.resume()
        self.timer = timer
    }

    private func refresh() {
        send(id: 2, method: "account/rateLimits/read", params: NSNull())
        send(id: 3, method: "account/usage/read", params: NSNull())
    }

    private func send(id: Int, method: String, params: Any) {
        write(["id": id, "method": method, "params": params])
    }

    private func sendNotification(method: String, params: Any) {
        write(["method": method, "params": params])
    }

    private func write(_ object: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(object),
              var data = try? JSONSerialization.data(withJSONObject: object) else { return }
        data.append(0x0A)
        try? stdin?.write(contentsOf: data)
    }

    private func resolveCodexExecutable() -> URL? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }

    private func publishError(_ message: String) {
        Task { @MainActor [weak self] in self?.model?.showConnectionError(message) }
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }
}
