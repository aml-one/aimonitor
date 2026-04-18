import SwiftUI

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
                             value: String(format: "%.1f%%", svc.ollamaStats.cpu))
                    statItem(label: "MEM",
                             value: String(format: "%.2f GB", svc.ollamaStats.memGB))
                    statItem(label: "MODELS",
                             value: "\(svc.ollamaModels.count)")
                }
                .padding(.bottom, 6)

                // Models list — always reserve height so card never jumps
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

                // CPU graph
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU USAGE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    LiveGraphView(values: svc.ollamaCPUHistory, color: accent)
                        .frame(height: 94)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.bottom, 6)

                // Action buttons
                HStack(spacing: 8) {
                    ActionButton(icon: "arrow.clockwise", label: "Restart",
                                 color: accent) {
                        svc.restartOllama()
                    }
                    Spacer()
                }
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - ComfyUI service card

struct ComfyCard: View {
    @EnvironmentObject var svc: ServiceMonitor
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
                             value: String(format: "%.1f%%", svc.comfyStats.cpu))
                    statItem(label: "MEM",
                             value: String(format: "%.2f GB", svc.comfyStats.memGB))
                    statItem(label: "QUEUE",
                             value: "\(svc.comfyQueueRunning) / \(svc.comfyQueuePending)")
                }
                .padding(.bottom, 6)

                // Queue indicator bars — always reserve height so card never jumps
                VStack(spacing: 0) {
                    queueBar(label: "Running",  count: svc.comfyQueueRunning,  color: accent)
                    queueBar(label: "Pending",  count: svc.comfyQueuePending,  color: accent.opacity(0.5))
                }
                .opacity(svc.comfyOnline ? 1 : 0)

                // CPU graph
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU USAGE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    LiveGraphView(values: svc.comfyCPUHistory, color: accent)
                        .frame(height: 94)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.bottom, 6)

                // Action buttons
                HStack(spacing: 8) {
                    ActionButton(icon: "xmark.circle", label: "Close",
                                 color: accent) {
                        svc.closeComfyUI()
                    }
                    ActionButton(icon: "trash", label: "Clear Queue",
                                 color: accent.opacity(0.8)) {
                        svc.clearComfyQueue()
                    }
                    Spacer()
                }
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func queueBar(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 50, alignment: .leading)
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
                .frame(width: 20, alignment: .trailing)
        }
        .padding(.bottom, 6)
    }
}
