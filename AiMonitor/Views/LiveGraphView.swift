import SwiftUI

/// Animated smooth area / line graph rendered with Canvas
struct LiveGraphView: View {
    let values: [Double]    // 0…1 normalised
    let color: Color
    var lineWidth: CGFloat = 2

    var body: some View {
        Canvas { ctx, size in
            guard values.count >= 2 else { return }

            let w = size.width
            let h = size.height
            let step = w / CGFloat(values.count - 1)

            // Helper: map index → point
            func pt(_ i: Int) -> CGPoint {
                let x = CGFloat(i) * step
                let v = min(max(values[i], 0), 1)
                let y = h - v * h * 0.88 - h * 0.06
                return CGPoint(x: x, y: y)
            }

            // Build smooth bezier paths
            var area = Path()
            var line = Path()

            let first = pt(0)
            area.move(to: CGPoint(x: 0, y: h))
            area.addLine(to: first)
            line.move(to: first)

            for i in 1..<values.count {
                let prev = pt(i - 1)
                let curr = pt(i)
                let cx   = (prev.x + curr.x) / 2
                let cp1  = CGPoint(x: cx, y: prev.y)
                let cp2  = CGPoint(x: cx, y: curr.y)
                area.addCurve(to: curr, control1: cp1, control2: cp2)
                line.addCurve(to: curr, control1: cp1, control2: cp2)
            }

            // Close area
            area.addLine(to: CGPoint(x: w, y: h))
            area.addLine(to: CGPoint(x: 0, y: h))
            area.closeSubpath()

            // Draw area fill
            ctx.fill(
                area,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: color.opacity(0.45), location: 0),
                        .init(color: color.opacity(0.08), location: 0.7),
                        .init(color: color.opacity(0.0),  location: 1),
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint:   CGPoint(x: 0, y: h)
                )
            )

            // Draw glowing line (two passes)
            ctx.stroke(line, with: .color(color.opacity(0.3)),
                       style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round, lineJoin: .round))
            ctx.stroke(line, with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            // Draw last-value dot
            if let last = values.last {
                let dotPt = pt(values.count - 1)
                let dotRect = CGRect(x: dotPt.x - 4, y: dotPt.y - 4, width: 8, height: 8)
                let _ = last // suppress warning
                ctx.fill(Path(ellipseIn: dotRect.insetBy(dx: 2, dy: 2)), with: .color(color))
                ctx.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.3)))
            }
        }
        .animation(.linear(duration: 0.4), value: values.last ?? 0)
    }
}

// MARK: - Tick labels helper (optional, not used in cards but handy)

struct GraphAxisLabel: View {
    let value: Double
    let unit: String
    var body: some View {
        Text("\(Int(value * 100))\(unit)")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.35))
    }
}
