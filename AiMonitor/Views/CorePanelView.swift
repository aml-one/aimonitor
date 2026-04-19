import SwiftUI

// MARK: - Single core mini-card (with live graph)

private struct CoreMiniCard: View {
    let index: Int            // 0-based
    let history: [Double]     // 0…1, last 60 samples
    let accent: Color

    private var current: Double { history.last ?? 0 }
    private var pct: Double     { current * 100 }

    // Accent normally; red only when >93%
    private var lineColor: Color {
        pct > 93 ? .red.opacity(0.85) : accent
    }

    private var valueLabel: String {
        if pct < 4 { return "idle" }
        return "\(Int(pct.rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Top row: label + value
            HStack {
                Text("Core \(index + 1)")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.38))
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(pct < 4 ? .white.opacity(0.3) : .white)
                    .frame(minWidth: 34, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.top, 7)

            // Mini graph — full width, flush to card edges
            LiveGraphView(values: history, color: lineColor, lineWidth: 1.5)
                .frame(height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(.bottom, 3)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                )
        )
    }
}

// MARK: - Compact queue bars (used in ComfyCorePanel header)

private struct CompactQueueBars: View {
    let running: Int
    let pending: Int
    let isGenerating: Bool
    let progress: Double
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            compactBar(label: "Running",    count: Double(running),  max: 10, color: accent)
            compactBar(label: "Pending",    count: Double(pending),  max: 10, color: accent.opacity(0.55))
            if isGenerating {
                compactBar(label: "Generating", count: progress, max: 1.0,
                           color: accent, isPercent: true)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isGenerating)
        .frame(width: 180)
    }

    @ViewBuilder
    private func compactBar(label: String, count: Double, max: Double,
                            color: Color, isPercent: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 58, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.06)).frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(width: g.size.width * min(count / max, 1.0), height: 4)
                        .animation(.easeInOut(duration: 0.3), value: count)
                }
            }
            .frame(height: 4)
            Text(isPercent ? String(format: "%.0f%%", count * 100) : "\(Int(count))")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 24, alignment: .trailing)
        }
    }
}

// MARK: - System-wide per-core load panel

struct SystemCorePanel: View {
    @EnvironmentObject var sys: SystemMonitor
    private let accent = Color(red: 0.55, green: 0.75, blue: 1.00)   // same sky-blue as CPU card
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        GlassCard(accentGlow: accent) {
            VStack(alignment: .leading, spacing: 10) {

                // ── Header ────────────────────────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 28, height: 28)
                        .background(accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("Load per cores")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    Text("\(sys.cpuCoreCount) cores")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }

                // ── Divider ───────────────────────────────────────────────
                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(height: 1)

                // ── Core grid ─────────────────────────────────────────────
                if sys.cpuCoreHistories.isEmpty {
                    Text("No core data yet…")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(sys.cpuCoreHistories.enumerated()), id: \.offset) { idx, hist in
                            CoreMiniCard(index: idx, history: hist, accent: accent)
                        }
                    }
                }
            }
            .padding(10)
        }
    }
}
