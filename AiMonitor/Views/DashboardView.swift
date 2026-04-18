import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var sys: SystemMonitor
    @EnvironmentObject var svc: ServiceMonitor
    @EnvironmentObject var api: APIServer

    // Pastel palette
    private let cpuColor  = Color(red: 0.55, green: 0.75, blue: 1.00)   // soft sky-blue
    private let memColor  = Color(red: 0.77, green: 0.58, blue: 1.00)   // soft lavender
    private let gpuColor  = Color(red: 0.52, green: 1.00, blue: 0.76)   // soft mint

    var body: some View {
        VStack(spacing: 10) {
            headerView
            systemSection
            servicesSection
            selfSection
            footerSpacer
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [cpuColor, memColor, gpuColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    Text("Ai Monitor")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("by AmL")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .offset(y: 5)
                        .padding(.leading, -9)
                }
                Text("Apple Silicon  ·  Live  ·  \(refreshDateString())")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.28))
            }

            Spacer()

            // API server badge
            apiBadge
                .padding(.trailing, 10)

            // System summary capsule — fixed width so numbers don't shift layout
            HStack(spacing: 0) {
                summaryChip(label: "CPU",  value: String(format: "%.0f%%", sys.cpuUsage * 100),
                            color: cpuColor)
                separatorLine()
                summaryChip(label: "MEM",  value: String(format: "%.0f%%",
                            sys.memoryTotalGB > 0 ? sys.memoryUsedGB / sys.memoryTotalGB * 100 : 0),
                            color: memColor)
                separatorLine()
                summaryChip(label: "GPU",  value: sys.gpuAvailable ? String(format: "%.0f%%", sys.gpuUsage * 100) : "N/A",
                            color: gpuColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1))
            )
        }
    }

    // MARK: - API badge

    private var apiBadge: some View {
        HStack(alignment: .top, spacing: 6) {
            LiveDot(color: api.isRunning ? Color(red: 0.55, green: 0.75, blue: 1.0) : .red.opacity(0.7))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(api.isRunning ? "API  ·  \(String(api.serverPort))" : "API  ·  OFF")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(api.isRunning ? Color(red: 0.55, green: 0.75, blue: 1.0) : .red.opacity(0.7))
                Text(api.isRunning ? "\(formatRequestCount(api.requestCount)) req" : (api.lastError ?? "stopped"))
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            (api.isRunning ? Color(red: 0.55, green: 0.75, blue: 1.0) : Color.red)
                                .opacity(0.20),
                            lineWidth: 1
                        )
                )
        )
        .onTapGesture { api.isRunning ? api.stop() : api.start() }
        .help(api.isRunning
            ? "API running on http://localhost:\(String(api.serverPort))/stats — tap to stop"
            : "API stopped — tap to start")
    }

    // MARK: - System section

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("SYSTEM RESOURCES")

            // Adaptive grid: 3 cards on wide, 1 per row on narrow
            HStack(spacing: 16) {
                MetricCard(
                    title: "CPU Usage",
                    icon: "cpu",
                    valueText: String(format: "%.0f%%", sys.cpuUsage * 100),
                    subtitle: "\(sys.cpuCoreCount) logical cores",
                    history: sys.cpuHistory,
                    accent: cpuColor
                )

                MetricCard(
                    title: "Memory",
                    icon: "memorychip",
                    valueText: String(format: "%.1f GB", sys.memoryUsedGB),
                    subtitle: "of \(String(format: "%.0f", sys.memoryTotalGB)) GB total",
                    history: sys.memoryHistory,
                    accent: memColor
                )

                MetricCard(
                    title: "GPU",
                    icon: "square.3.layers.3d",
                    valueText: sys.gpuAvailable
                        ? String(format: "%.0f%%", sys.gpuUsage * 100)
                        : "—",
                    subtitle: sys.gpuAvailable ? "Apple Silicon" : "unavailable",
                    history: sys.gpuHistory,
                    accent: gpuColor
                )
            }
        }
    }

    // MARK: - Services section

    @ViewBuilder
    private var servicesSection: some View {
        let showOllama = svc.ollamaInstalled
        let showComfy  = svc.comfyInstalled

        if showOllama || showComfy {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("AI SERVICES")

                HStack(alignment: .top, spacing: 16) {
                    if showOllama { OllamaCard().frame(maxHeight: .infinity) }
                    if showComfy  { ComfyCard().fixedSize(horizontal: false, vertical: true)  }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Self section

    private let selfAccent = Color(red: 1.0, green: 0.85, blue: 0.45)
    @AppStorage("reducedUpdates") private var reducedUpdates: Bool = false

    private var selfSection: some View {
        HStack(spacing: 12) {
            Text("THIS APP")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.25))
            selfChip(icon: "cpu", label: "CPU",
                     value: String(format: "%.1f%%", sys.selfCPU * 100))
            Rectangle().fill(.white.opacity(0.08)).frame(width: 1, height: 16)
            selfChip(icon: "memorychip", label: "RAM",
                     value: sys.selfMemoryMB >= 1024
                        ? String(format: "%.2f GB", sys.selfMemoryMB / 1024)
                        : String(format: "%.0f MB", sys.selfMemoryMB))

            Spacer()

            Toggle(isOn: Binding(
                get: { reducedUpdates },
                set: { newVal in
                    reducedUpdates = newVal
                    sys.setInterval(newVal ? 1.0 : 0.3)
                }
            )) {
                Text("reduced updates")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.30))
            }
            .toggleStyle(.checkbox)
            .controlSize(.mini)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func selfChip(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(selfAccent)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(selfAccent)
        }
    }

    // MARK: - Footer

    private var footerSpacer: some View {
        Text(reducedUpdates ? "Updates every 1s (reduced)  ·  AI Monitor by AmL"
                            : "Updates every 300ms  ·  AI Monitor by AmL")
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundStyle(.white.opacity(0.18))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.28))
    }

    @ViewBuilder
    private func separatorLine() -> some View {
        Rectangle()
            .fill(.white.opacity(0.10))
            .frame(width: 1, height: 28)
            .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func summaryChip(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            // Fixed frame wide enough for "100%" — prevents layout shifts
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .frame(width: 52, alignment: .center)
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))
                .frame(width: 52, alignment: .center)
        }
    }

    private func refreshDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    private func formatRequestCount(_ count: Int) -> String {
        guard count >= 100_000 else { return "\(count)" }
        return "\(count / 1000)k"
    }
}
