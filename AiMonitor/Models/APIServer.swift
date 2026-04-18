import Foundation
import Network

// MARK: - APIServer
// Exposes a tiny HTTP/1.1 JSON API on localhost:<port> (default 9876).
//
// Endpoints:
//   GET /          → same as /stats
//   GET /stats     → full snapshot (system + services)
//   GET /system    → CPU / Memory / GPU only
//   GET /services  → Ollama + ComfyUI only
//
// All responses include CORS headers so any web app or remote client can fetch them.

@MainActor
final class APIServer: ObservableObject {

    // MARK: - Published state

    @Published var isRunning    = false
    @Published var serverPort: UInt16 = 9876
    @Published var requestCount = 0
    @Published var lastError: String?

    // MARK: - Private

    private var listener:    NWListener?
    private var connections: [NWConnection] = []

    private weak var sys: SystemMonitor?
    private weak var svc: ServiceMonitor?

    // MARK: - Init

    init(sys: SystemMonitor, svc: ServiceMonitor) {
        self.sys = sys
        self.svc = svc
    }

    // MARK: - Lifecycle

    func start(port: UInt16 = 9876) {
        guard !isRunning else { return }
        serverPort = port
        lastError  = nil

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                lastError = "Invalid port \(port)"; return
            }
            listener = try NWListener(using: params, on: nwPort)
        } catch {
            lastError = error.localizedDescription; return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.isRunning  = true
                    self?.lastError  = nil
                case .failed(let err):
                    self?.isRunning  = false
                    self?.lastError  = err.localizedDescription
                    self?.listener?.cancel()
                case .cancelled:
                    self?.isRunning  = false
                default:
                    break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.accept(connection)
            }
        }

        listener?.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        isRunning = false
    }

    func restart() {
        stop()
        start(port: serverPort)
    }

    // MARK: - Connection handling

    private func accept(_ conn: NWConnection) {
        connections.append(conn)
        conn.start(queue: .global(qos: .utility))
        receive(from: conn)
    }

    private func receive(from conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            guard let self else { conn.cancel(); return }

            if let data, !data.isEmpty {
                let raw = String(decoding: data, as: UTF8.self)
                Task { @MainActor [weak self] in
                    self?.process(raw, on: conn)
                }
            } else {
                conn.cancel()
            }
        }
    }

    private func process(_ raw: String, on conn: NWConnection) {
        // Parse first line: "GET /path HTTP/1.1"
        let firstLine = raw.components(separatedBy: "\r\n").first ?? raw.components(separatedBy: "\n").first ?? ""
        let parts     = firstLine.split(separator: " ", omittingEmptySubsequences: true)
        let method    = parts.count >= 1 ? String(parts[0]) : "GET"
        let fullPath  = parts.count >= 2 ? String(parts[1]) : "/"
        let path      = fullPath.components(separatedBy: "?").first ?? fullPath

        // OPTIONS preflight
        if method == "OPTIONS" {
            requestCount += 1
            let response = httpResponse(status: 200, body: "{}")
            if let d = response.data(using: .utf8) {
                conn.send(content: d, completion: .contentProcessed { _ in conn.cancel() })
            } else { conn.cancel() }
            connections.removeAll { $0.state == .cancelled }
            return
        }

        let (statusCode, body): (Int, String)
        if method == "GET" {
            switch path {
            case "/", "/stats":
                statusCode = 200
                body = buildFullStats()
            case "/system":
                statusCode = 200
                body = buildSystemStats()
            case "/services":
                statusCode = 200
                body = buildServiceStats()
            default:
                statusCode = 404
                body = jsonError("Not found", extra: """
                    ,"endpoints":["/stats","/system","/services","/actions/ollama/restart","/actions/comfy/close","/actions/comfy/clear-queue"]
                    """)
            }
        } else if method == "POST" {
            switch path {
            case "/actions/ollama/restart":
                svc?.restartOllama()
                statusCode = 200
                body = "{\"ok\":true,\"action\":\"ollama_restart\"}"
            case "/actions/comfy/close":
                svc?.closeComfyUI()
                statusCode = 200
                body = "{\"ok\":true,\"action\":\"comfy_close\"}"
            case "/actions/comfy/clear-queue":
                svc?.clearComfyQueue()
                statusCode = 200
                body = "{\"ok\":true,\"action\":\"comfy_clear_queue\"}"
            default:
                statusCode = 404
                body = jsonError("Not found")
            }
        } else {
            statusCode = 405
            body = jsonError("Method not allowed. Use GET or POST.")
        }

        requestCount += 1
        let response = httpResponse(status: statusCode, body: body)

        if let responseData = response.data(using: .utf8) {
            conn.send(content: responseData, completion: .contentProcessed { _ in
                conn.cancel()
            })
        } else {
            conn.cancel()
        }

        // Prune dead connections
        connections.removeAll { $0.state == .cancelled }
    }

    // MARK: - JSON builders

    private func buildFullStats() -> String {
        let s = buildSystemDict()
        let v = buildServicesDict()
        let ts = ISO8601DateFormatter().string(from: Date())
        return """
        {
          "timestamp": "\(ts)",
          "system": \(s),
          "services": \(v)
        }
        """
    }

    private func buildSystemStats() -> String {
        let ts = ISO8601DateFormatter().string(from: Date())
        return """
        {
          "timestamp": "\(ts)",
          \(buildSystemDict().dropFirst().dropLast())
        }
        """
    }

    private func buildServiceStats() -> String {
        let ts = ISO8601DateFormatter().string(from: Date())
        return """
        {
          "timestamp": "\(ts)",
          \(buildServicesDict().dropFirst().dropLast())
        }
        """
    }

    private func buildSystemDict() -> String {
        guard let sys else { return "{}" }

        let cpuPct  = (sys.cpuUsage * 100).rounded(dp: 2)
        let memUsed = sys.memoryUsedGB.rounded(dp: 3)
        let memTot  = sys.memoryTotalGB.rounded(dp: 1)
        let memPct  = sys.memoryTotalGB > 0
            ? (sys.memoryUsedGB / sys.memoryTotalGB * 100).rounded(dp: 2)
            : 0.0
        let gpuPct  = sys.gpuAvailable ? (sys.gpuUsage * 100).rounded(dp: 2) : -1.0

        let cpuHist = sys.cpuHistory.map   { ($0 * 100).rounded(dp: 1) }.jsonArray()
        let memHist = sys.memoryHistory.map { ($0 * 100).rounded(dp: 1) }.jsonArray()
        let gpuHist = sys.gpuHistory.map   { ($0 * 100).rounded(dp: 1) }.jsonArray()

        return """
        {
            "cpu": {
              "usage_pct": \(cpuPct),
              "core_count": \(sys.cpuCoreCount),
              "history_pct": \(cpuHist)
            },
            "memory": {
              "used_gb": \(memUsed),
              "total_gb": \(memTot),
              "usage_pct": \(memPct),
              "history_pct": \(memHist)
            },
            "gpu": {
              "available": \(sys.gpuAvailable),
              "usage_pct": \(gpuPct == -1.0 ? "null" : String(gpuPct)),
              "history_pct": \(gpuHist)
            }
          }
        """
    }

    private func buildServicesDict() -> String {
        guard let svc else { return "{}" }

        let ollamaCPUHist = svc.ollamaCPUHistory.map { ($0 * 100).rounded(dp: 1) }.jsonArray()
        let comfyCPUHist  = svc.comfyCPUHistory.map  { ($0 * 100).rounded(dp: 1) }.jsonArray()

        let models: String
        if svc.ollamaModels.isEmpty {
            models = "[]"
        } else {
            let items = svc.ollamaModels.map { m in
                "{\"name\":\"\(m.name)\",\"size_gb\":\(m.sizeGB.rounded(dp: 3))}"
            }.joined(separator: ",")
            models = "[\(items)]"
        }

        return """
        {
            "ollama": {
              "installed": \(svc.ollamaInstalled),
              "online": \(svc.ollamaOnline),
              "models": \(models),
              "cpu_pct": \(svc.ollamaStats.cpu.rounded(dp: 2)),
              "mem_gb": \(svc.ollamaStats.memGB.rounded(dp: 3)),
              "cpu_history_pct": \(ollamaCPUHist)
            },
            "comfyui": {
              "installed": \(svc.comfyInstalled),
              "online": \(svc.comfyOnline),
              "queue_running": \(svc.comfyQueueRunning),
              "queue_pending": \(svc.comfyQueuePending),
              "is_generating": \(svc.comfyIsGenerating),
              "generation_progress": \(svc.comfyGenerationProgress.rounded(dp: 3)),
              "cpu_pct": \(svc.comfyStats.cpu.rounded(dp: 2)),
              "mem_gb": \(svc.comfyStats.memGB.rounded(dp: 3)),
              "cpu_history_pct": \(comfyCPUHist)
            }
          }
        """
    }

    // MARK: - HTTP helpers

    private func httpResponse(status: Int, body: String) -> String {
        let reason  = HTTPStatus.reason(for: status)
        let bodyLen = body.utf8.count
        return """
        HTTP/1.1 \(status) \(reason)\r\n\
        Content-Type: application/json; charset=utf-8\r\n\
        Content-Length: \(bodyLen)\r\n\
        Access-Control-Allow-Origin: *\r\n\
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n\
        Access-Control-Allow-Headers: Content-Type, *\r\n\
        Cache-Control: no-cache\r\n\
        X-Powered-By: AiMonitor-by-AmL\r\n\
        Connection: close\r\n\
        \r\n\
        \(body)
        """
    }

    private func jsonError(_ message: String, extra: String = "") -> String {
        "{\"error\":\"\(message)\"\(extra)}"
    }
}

// MARK: - Tiny helpers

private enum HTTPStatus {
    static func reason(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        default:  return "Unknown"
        }
    }
}

private extension Double {
    func rounded(dp: Int) -> Double {
        let factor = pow(10.0, Double(dp))
        return (self * factor).rounded() / factor
    }
}

private extension [Double] {
    func jsonArray() -> String {
        "[" + map { String($0) }.joined(separator: ",") + "]"
    }
}
