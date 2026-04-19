import SwiftUI

func cpuString(_ cpu: Double) -> String {
    return String(format: cpu.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f%%" : "%.1f%%", cpu)
}

private func coreHint(_ cpu: Double) -> String? {
    let cores = Int(cpu / 100)
    guard cores > 0 else { return nil }
    return cores == 1 ? "1 core maxed out" : "\(cores) cores maxed out"
}

// MARK: - Status badge

struct StatusBadge: View {
    let online: Bool
    var body: some View {
        HStack(spacing: 5) {
            LiveDot(color: online ? .mint : .red.opacity(0.8))
            Text(online ? "ONLINE" : "OFFLINE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(online ? Color.mint : Color.red.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill((online ? Color.mint : Color.red).opacity(0.10))
        )
        .overlay(
            Capsule()
                .strokeBorder((online ? Color.mint : Color.red).opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Small action button

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(color.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ollama service card

struct OllamaCard: View {
    @EnvironmentObject var svc: ServiceMonitor
    @State private var confirmRestart = false
    private let accent = Color(red: 1.0, green: 0.72, blue: 0.53)   // pastel peach

    var body: some View {
        GlassCard(accentGlow: accent) {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack(spacing: 8) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 28, height: 28)
                        .background(accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Ollama")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("localhost:11434")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Spacer()
                    StatusBadge(online: svc.ollamaOnline)
                }
                .padding(.bottom, 6)

                // Stats row
                HStack(spacing: 20) {
                    statItem(label: "CPU",
                             value: svc.ollamaStats.cpu < 0.35 ? "idle" : cpuString(svc.ollamaStats.cpu),
                             valueColor: svc.ollamaStats.cpu < 0.35 ? .green : .white,
                             minWidth: 86)
                    statItem(label: "MEM",
                             value: svc.ollamaStats.memGB < 1.0 ? String(format: "%.0f MB", svc.ollamaStats.memGB * 1024) : String(format: "%.2f GB", svc.ollamaStats.memGB),
                             minWidth: 96)
                    statItem(label: "MODELS",
                             value: "\(svc.ollamaModels.count)",
                             minWidth: 64)
                }
                .opacity(svc.ollamaOnline ? 1 : 0)
                .padding(.bottom, 6)

                // Models list + generation-bar-height spacer (matches ComfyCard height)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(svc.ollamaModels) { m in
                            Text(m.name)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(accent.opacity(0.12)))
                                .overlay(Capsule().strokeBorder(accent.opacity(0.22), lineWidth: 1))
                        }
                        if svc.ollamaModels.isEmpty {
                            // placeholder to keep height stable
                            Text(" ")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .opacity(0)
                        }
                    }
                }
                .frame(height: 26)
                .opacity(svc.ollamaOnline ? 1 : 0)
                .padding(.bottom, 6)

                Spacer()

                // CPU graph
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CPU USAGE")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                        Spacer()
                        Text("100% = 1 core")
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.18))
                    }
                    .padding(.horizontal, 10)
                    LiveGraphView(values: svc.ollamaCPUHistory, color: accent)
                        .frame(height: 94)
                }
                .padding(.horizontal, -10)
                .padding(.bottom, 6)

                // Action buttons
                HStack(spacing: 8) {
                    ActionButton(icon: svc.ollamaOnline ? "arrow.clockwise" : "play.fill",
                                 label: svc.ollamaOnline ? "Restart" : "Start",
                                 color: accent) {
                        if svc.ollamaOnline {
                            confirmRestart = true
                        } else {
                            svc.restartOllama()
                        }
                    }
                    .confirmationDialog("Restart Ollama?", isPresented: $confirmRestart, titleVisibility: .visible) {
                        Button("Restart", role: .destructive) { svc.restartOllama() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will kill and restart the Ollama process.")
                    }
                    Spacer()
                    if let hint = coreHint(svc.ollamaStats.cpu) {
                        Text(hint)
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(.red.opacity(0.45))
                    }
                }
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func statItem(label: String, value: String, valueColor: Color = .white, minWidth: CGFloat = 64) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
        }
        .frame(minWidth: minWidth, alignment: .leading)
    }
}

// MARK: - ComfyUI service card

struct ComfyCard: View {
    @EnvironmentObject var svc: ServiceMonitor
    @State private var confirmClose = false
    private let accent = Color(red: 1.0, green: 0.55, blue: 0.75)   // pastel pink

    var body: some View {
        GlassCard(accentGlow: accent) {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack(spacing: 8) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 28, height: 28)
                        .background(accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("ComfyUI")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("localhost:8188")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Spacer()
                    StatusBadge(online: svc.comfyOnline)
                }
                .padding(.bottom, 6)

                // Stats row
                HStack(spacing: 20) {
                    statItem(label: "CPU",
                             value: svc.comfyStats.cpu < 0.35 ? "idle" : cpuString(svc.comfyStats.cpu),
                             valueColor: svc.comfyStats.cpu < 0.35 ? .green : .white,
                             minWidth: 86)
                    statItem(label: "MEM",
                             value: svc.comfyStats.memGB < 1.0 ? String(format: "%.0f MB", svc.comfyStats.memGB * 1024) : String(format: "%.2f GB", svc.comfyStats.memGB),
                             minWidth: 96)
                    statItem(label: "QUEUE",
                             value: "\(svc.comfyQueueRunning) / \(svc.comfyQueuePending)",
                             minWidth: 72)
                }
                .opacity(svc.comfyOnline ? 1 : 0)
                .padding(.bottom, 6)

                // Queue indicator bars + generation progress — always reserve height so card never jumps
                VStack(spacing: 0) {
                    queueBar(label: "Running",  count: svc.comfyQueueRunning,  color: accent)
                    queueBar(label: "Pending",  count: svc.comfyQueuePending,  color: accent.opacity(0.5))
                    generationBar(progress: svc.comfyGenerationProgress, color: accent)
                        .opacity(svc.comfyIsGenerating ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4), value: svc.comfyIsGenerating)
                }
                .opacity(svc.comfyOnline ? 1 : 0)

                // CPU graph
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CPU USAGE")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                        Spacer()
                        Text("100% = 1 core")
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.18))
                    }
                    .padding(.horizontal, 10)
                    LiveGraphView(values: svc.comfyCPUHistory, color: accent)
                        .frame(height: 94)
                }
                .padding(.horizontal, -10)
                .padding(.bottom, 6)

                // Action buttons
                HStack(spacing: 8) {
                    ActionButton(icon: "xmark.circle", label: "Close",
                                 color: accent) {
                        confirmClose = true
                    }
                    .confirmationDialog("Close ComfyUI?", isPresented: $confirmClose, titleVisibility: .visible) {
                        Button("Close", role: .destructive) { svc.closeComfyUI() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will terminate the ComfyUI process.")
                    }
                    ActionButton(icon: "trash", label: "Clear Queue",
                                 color: accent.opacity(0.8)) {
                        svc.clearComfyQueue()
                    }
                    Spacer()
                    if let hint = coreHint(svc.comfyStats.cpu) {
                        Text(hint)
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(.red.opacity(0.45))
                    }
                }
                .opacity(svc.comfyOnline ? 1 : 0)
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func statItem(label: String, value: String, valueColor: Color = .white, minWidth: CGFloat = 64) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
        }
        .frame(minWidth: minWidth, alignment: .leading)
    }

    @ViewBuilder
    private func generationBar(progress: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text("Generating")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color.opacity(0.85))
                .frame(width: 72, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.05)).frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: g.size.width * max(progress, 0.02), height: 6)
                        .animation(.easeInOut(duration: 0.25), value: progress)
                }
            }
            .frame(height: 6)
            Text(String(format: "%.0f%%", progress * 100))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func queueBar(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 72, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.05)).frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: g.size.width * min(CGFloat(count) / 10.0, 1.0), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: count)
                }
            }
            .frame(height: 6)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.bottom, 6)
    }
}
