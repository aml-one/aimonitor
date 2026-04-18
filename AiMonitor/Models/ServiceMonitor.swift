import Foundation

struct OllamaModel: Identifiable {
    let id = UUID()
    let name: String
    let sizeGB: Double
}

struct ProcessStats {
    var cpu: Double = 0
    var memGB: Double = 0
}

@MainActor
class ServiceMonitor: ObservableObject {

    // MARK: - Installation detection
    @Published var ollamaInstalled: Bool = false
    @Published var comfyInstalled:  Bool = false

    // MARK: - Ollama
    @Published var ollamaOnline: Bool = false
    @Published var ollamaModels: [OllamaModel] = []
    @Published var ollamaStats = ProcessStats()
    @Published var ollamaCPUHistory:  [Double] = Array(repeating: 0, count: 60)

    // MARK: - ComfyUI
    @Published var comfyOnline: Bool = false
    @Published var comfyQueuePending: Int = 0
    @Published var comfyQueueRunning: Int = 0
    @Published var comfyStats = ProcessStats()
    @Published var comfyCPUHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var comfyIsGenerating: Bool = false
    @Published var comfyGenerationProgress: Double = 0.0

    private var timer: Timer?
    private var session: URLSession
    private var comfyWSTask: URLSessionWebSocketTask?
    private let comfyClientId = UUID().uuidString

    // Node-level progress tracking
    private var comfyTotalNodes: Int = 0
    private var comfyCompletedNodes: Int = 0
    private var comfyCurrentNodeFraction: Double = 0

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 2
        cfg.timeoutIntervalForResource = 2
        session = URLSession(configuration: cfg)
        detectInstalled()
        startMonitoring()
    }

    // MARK: - Install detection

    private func detectInstalled() {
        let fm   = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        // Ollama: binary at standard paths, or as a macOS app
        let ollamaBins = ["/usr/local/bin/ollama", "/opt/homebrew/bin/ollama",
                          "/usr/bin/ollama", "/opt/local/bin/ollama"]
        ollamaInstalled = ollamaBins.contains { fm.fileExists(atPath: $0) }
                       || fm.fileExists(atPath: "/Applications/Ollama.app")

        // ComfyUI: common install directories (bare or inside Documents/Desktop/Downloads)
        let comfyRoots = [home, "\(home)/Documents", "\(home)/Desktop", "\(home)/Downloads",
                          "\(home)/Projects", "\(home)/dev", "\(home)/workspace"]
        let comfyNames = ["ComfyUI", "comfyui", "ComfyUI-main"]
        comfyInstalled = comfyRoots.contains { root in
            comfyNames.contains { name in
                fm.fileExists(atPath: "\(root)/\(name)/main.py")
            }
        } || fm.fileExists(atPath: "/Applications/ComfyUI.app")
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }
        Task { @MainActor in await refresh() }
    }

    // MARK: - Main refresh

    private func refresh() async {
        async let ollama: Void = pollOllama()
        async let comfy:  Void = pollComfyUI()
        _ = await (ollama, comfy)

        let olStats = await fetchProcessStats(name: "ollama")
        let pyStats = await fetchProcessStats(name: "python")

        ollamaStats = olStats
        comfyStats  = pyStats

        appendHistory(&ollamaCPUHistory, value: min(olStats.cpu / 100.0, 1))
        appendHistory(&comfyCPUHistory,  value: min(pyStats.cpu / 100.0, 1))
    }

    private func appendHistory(_ arr: inout [Double], value: Double) {
        arr.append(value)
        if arr.count > 60 { arr.removeFirst() }
    }

    // MARK: - Ollama

    private func pollOllama() async {
        guard let url = URL(string: "http://127.0.0.1:11434/api/ps") else { return }
        do {
            let (data, resp) = try await session.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                ollamaOnline = false; return
            }
            ollamaOnline = true

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                ollamaModels = models.compactMap { m -> OllamaModel? in
                    guard let name = m["name"] as? String else { return nil }
                    let sizeBytes = (m["size"] as? Double) ?? 0
                    return OllamaModel(name: name, sizeGB: sizeBytes / 1_073_741_824)
                }
            }
        } catch {
            ollamaOnline = false
            ollamaModels = []
        }
    }

    // MARK: - ComfyUI

    private func pollComfyUI() async {
        guard let url = URL(string: "http://127.0.0.1:8188/system_stats") else { return }
        do {
            let (_, resp) = try await session.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                if comfyOnline { disconnectComfyWS() }
                comfyOnline = false
                return
            }
            let wasOffline = !comfyOnline
            comfyOnline = true
            if wasOffline { connectComfyWS() }
            await fetchComfyQueue()
        } catch {
            if comfyOnline { disconnectComfyWS() }
            comfyOnline = false
        }
    }

    // MARK: - ComfyUI WebSocket (generation progress)

    private func connectComfyWS() {
        guard let url = URL(string: "ws://127.0.0.1:8188/ws?clientId=\(comfyClientId)") else { return }
        comfyWSTask?.cancel()
        comfyWSTask = session.webSocketTask(with: url)
        comfyWSTask?.resume()
        receiveComfyWS()
    }

    private func disconnectComfyWS() {
        comfyWSTask?.cancel()
        comfyWSTask = nil
        comfyIsGenerating = false
        comfyGenerationProgress = 0
        comfyTotalNodes = 0
        comfyCompletedNodes = 0
        comfyCurrentNodeFraction = 0
    }

    private func receiveComfyWS() {
        comfyWSTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                Task { @MainActor [weak self] in
                    self?.handleComfyWSMessage(message)
                    self?.receiveComfyWS()
                }
            case .failure:
                Task { @MainActor [weak self] in
                    self?.comfyWSTask = nil
                }
            }
        }
    }

    private func handleComfyWSMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "execution_start":
            comfyIsGenerating = true
            comfyGenerationProgress = 0
            comfyCompletedNodes = 0
            comfyCurrentNodeFraction = 0
            comfyTotalNodes = 0
            // Fetch total node count for this prompt from the running queue
            Task { [weak self] in await self?.fetchComfyRunningNodeCount() }

        case "executing":
            guard let ed = json["data"] as? [String: Any] else { break }
            let node = ed["node"]
            if node == nil || node is NSNull {
                // Workflow finished
                comfyIsGenerating = false
                comfyGenerationProgress = 0
                comfyCompletedNodes = 0
                comfyCurrentNodeFraction = 0
            } else {
                // A new node started — count the previous one as done
                comfyCompletedNodes += 1
                comfyCurrentNodeFraction = 0
                updateComfyGlobalProgress()
            }

        case "execution_cached":
            // Cached nodes count as instantly completed
            if let cd = json["data"] as? [String: Any],
               let nodes = cd["nodes"] as? [Any] {
                comfyCompletedNodes += nodes.count
                updateComfyGlobalProgress()
            }

        case "progress":
            if let pd = json["data"] as? [String: Any],
               let value = (pd["value"] as? NSNumber)?.doubleValue,
               let max   = (pd["max"]   as? NSNumber)?.doubleValue, max > 0 {
                comfyCurrentNodeFraction = value / max
                updateComfyGlobalProgress()
            }

        default:
            break
        }
    }

    private func updateComfyGlobalProgress() {
        guard comfyTotalNodes > 0 else {
            // Total unknown yet — fall back to per-node fraction, never go backward
            let p = comfyCurrentNodeFraction
            if p > comfyGenerationProgress { comfyGenerationProgress = p }
            return
        }
        let total = Double(comfyTotalNodes)
        let global = (Double(comfyCompletedNodes) + comfyCurrentNodeFraction) / total
        // High-water mark: never go backward
        let clamped = min(max(global, 0), 0.99)
        if clamped > comfyGenerationProgress { comfyGenerationProgress = clamped }
    }

    private func fetchComfyRunningNodeCount() async {
        guard let url = URL(string: "http://127.0.0.1:8188/queue") else { return }
        guard let (data, _) = try? await session.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let running = json["queue_running"] as? [[Any]],
              let first = running.first,
              first.count >= 3,
              let graph = first[2] as? [String: Any] else { return }
        // The prompt graph is a dict of nodeId -> node definition
        let count = graph.count
        await MainActor.run { [weak self] in
            guard let self, count > 0 else { return }
            self.comfyTotalNodes = count
            self.updateComfyGlobalProgress()
        }
    }

    private func fetchComfyQueue() async {
        guard let url = URL(string: "http://127.0.0.1:8188/queue") else { return }
        do {
            let (data, _) = try await session.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                comfyQueuePending = (json["queue_pending"] as? [[Any]])?.count ?? 0
                comfyQueueRunning = (json["queue_running"] as? [[Any]])?.count ?? 0
            }
        } catch {}
    }

    // MARK: - Process stats (via ps)

    nonisolated private func fetchProcessStats(name: String) async -> ProcessStats {
        return await Task.detached(priority: .utility) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["-axo", "pcpu,rss,comm"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError  = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
            } catch { return ProcessStats() }

            let raw = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let txt = String(data: raw, encoding: .utf8) else { return ProcessStats() }

            var totalCPU = 0.0
            var totalMem = 0.0
            for line in txt.components(separatedBy: "\n") {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 3 else { continue }
                let comm = parts[2...].joined(separator: " ").lowercased()
                guard comm.contains(name.lowercased()) else { continue }
                if let cpu = Double(parts[0]) { totalCPU += cpu }
                if let rss = Double(parts[1]) { totalMem += rss / 1_048_576 }
            }
            return ProcessStats(cpu: totalCPU, memGB: totalMem)
        }.value
    }

    // MARK: - Actions

    /// Stop and restart the Ollama background service
    func restartOllama() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c",
            "pkill -x ollama 2>/dev/null; sleep 1; " +
            "open -a Ollama 2>/dev/null || " +
            "{ /usr/local/bin/ollama serve &>/dev/null & } || " +
            "{ /opt/homebrew/bin/ollama serve &>/dev/null & }"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice
        try? task.run()
    }

    /// Kill the ComfyUI Python process
    func closeComfyUI() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "pkill -f 'main.py' 2>/dev/null; pkill -f '[Cc]omfy' 2>/dev/null"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice
        try? task.run()
    }

    /// POST to ComfyUI to clear the pending queue
    func clearComfyQueue() {
        Task {
            guard let url = URL(string: "http://127.0.0.1:8188/queue") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["clear": true])
            _ = try? await session.data(for: req)
        }
    }
}
