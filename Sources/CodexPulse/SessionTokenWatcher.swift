import Foundation

final class SessionTokenWatcher: @unchecked Sendable {
    private weak var model: PulseModel?
    private let queue = DispatchQueue(label: "codex-pulse.session-watcher")
    private var timer: DispatchSourceTimer?
    private var offsets: [String: UInt64] = [:]
    private var lastEventSignature = ""
    private var todayTotal: Int64 = 0

    init(model: PulseModel) {
        self.model = model
    }

    func start() {
        queue.async { [weak self] in
            self?.prime()
            self?.schedule()
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func schedule() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        self.timer = timer
    }

    private func prime() {
        for url in todaySessionFiles() {
            if let data = try? Data(contentsOf: url) {
                todayTotal += tokenTotals(in: data, publishRateLimit: false).reduce(0, +)
            }
            offsets[url.path] = fileSize(url)
        }
        let total = todayTotal
        Task { @MainActor [weak self] in
            self?.model?.applyUsage(today: total, lifetime: nil)
        }
    }

    private func poll() {
        for url in todaySessionFiles() {
            let oldOffset = offsets[url.path] ?? fileSize(url)
            let newSize = fileSize(url)
            guard newSize > oldOffset else {
                offsets[url.path] = newSize
                continue
            }
            guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? handle.close() }
            try? handle.seek(toOffset: oldOffset)
            let data = (try? handle.readToEnd()) ?? Data()
            offsets[url.path] = newSize
            consume(data)
        }
    }

    private func consume(_ data: Data) {
        let totals = tokenTotals(in: data, publishRateLimit: true)
        guard !totals.isEmpty else { return }
        todayTotal += totals.reduce(0, +)
        let currentTodayTotal = todayTotal

        Task { @MainActor [weak self] in
            self?.model?.applyUsage(today: currentTodayTotal, lifetime: nil)
        }

        for total in totals {
            Task { @MainActor [weak self] in
                self?.model?.react(tokens: total)
            }
        }
    }

    private func tokenTotals(in data: Data, publishRateLimit: Bool) -> [Int64] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var totals: [Int64] = []
        for line in text.split(separator: "\n") {
            guard let row = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  row["type"] as? String == "event_msg",
                  let payload = row["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let info = payload["info"] as? [String: Any],
                  let last = info["last_token_usage"] as? [String: Any],
                  let total = Self.int64(last["total_tokens"]), total > 0 else { continue }

            let signature = "\(total)-\(last["input_tokens"] ?? "")-\(last["output_tokens"] ?? "")"
            guard signature != lastEventSignature else { continue }
            lastEventSignature = signature
            totals.append(total)

            let usedPercent: Int? = {
                guard let rate = payload["rate_limits"] as? [String: Any],
                      let primary = rate["primary"] as? [String: Any] else { return nil }
                return Self.int(primary["used_percent"])
            }()
            if publishRateLimit {
                Task { @MainActor [weak self] in
                    if let usedPercent {
                        self?.model?.applyRateLimit(used: usedPercent, resetEpoch: nil, plan: nil, reserveUsed: nil)
                    }
                }
            }
        }
        return totals
    }

    private func todaySessionFiles() -> [URL] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions")
            .appendingPathComponent(formatter.string(from: Date()))
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return files.filter { $0.pathExtension == "jsonl" }
    }

    private func fileSize(_ url: URL) -> UInt64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(values?.fileSize ?? 0)
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
