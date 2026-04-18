import SwiftUI

/// Pulsing live indicator dot
struct LiveDot: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.25))
                .frame(width: 14, height: 14)
                .scaleEffect(pulse ? 1.8 : 1.0)
                .opacity(pulse ? 0 : 1)
            Circle().fill(color)
                .frame(width: 7, height: 7)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - System Metric Card (CPU / Memory / GPU)

struct MetricCard: View {
    let title: String
    let icon: String
    let valueText: String
    let subtitle: String
    let history: [Double]
    let accent: Color

    var body: some View {
        GlassCard(accentGlow: accent) {
            VStack(alignment: .leading, spacing: 0) {

                // Header + value — padded on all sides
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 22, height: 22)
                            .background(accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))

                        Spacer()
                        LiveDot(color: accent)
                    }
                    .padding(.bottom, 6)

                    // Value + subtitle stacked, centred
                    VStack(spacing: 1) {
                        Text(valueText)
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(subtitle)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.40))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // Graph — full bleed, clipped to card bottom corners
                LiveGraphView(values: history, color: accent)
                    .frame(height: 68)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0, bottomLeadingRadius: 14,
                            bottomTrailingRadius: 14, topTrailingRadius: 0,
                            style: .continuous
                        )
                    )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Percentage ring overlay (decorative)

struct PercentRing: View {
    let progress: Double
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [color.opacity(0.6), color],
                                    center: .center),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }
}
