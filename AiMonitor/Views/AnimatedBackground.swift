import SwiftUI

// MARK: - SwiftUI background with mesh-like animated gradient

struct AnimatedBackground: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { ctx, size in
                // Semi-transparent dark base — lets the desktop vibrancy bleed through
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(red: 0.04, green: 0.04, blue: 0.08, opacity: 0.78)))

                // Subtle animated soft glows
                let t  = timeline.date.timeIntervalSinceReferenceDate
                let w  = size.width
                let h  = size.height

                let blobs: [(x: CGFloat, y: CGFloat, r: CGFloat, c: Color)] = [
                    (w * 0.15 + CGFloat(sin(t * 0.18)) * 60,
                     h * 0.20 + CGFloat(cos(t * 0.14)) * 40,
                     300,
                     Color(red: 0.55, green: 0.75, blue: 1.0).opacity(0.06)),

                    (w * 0.80 + CGFloat(cos(t * 0.12)) * 70,
                     h * 0.30 + CGFloat(sin(t * 0.16)) * 50,
                     280,
                     Color(red: 0.77, green: 0.58, blue: 1.0).opacity(0.05)),

                    (w * 0.50 + CGFloat(sin(t * 0.10)) * 80,
                     h * 0.75 + CGFloat(cos(t * 0.11)) * 40,
                     320,
                     Color(red: 0.52, green: 1.00, blue: 0.76).opacity(0.04)),
                ]

                for blob in blobs {
                    let rect = CGRect(x: blob.x - blob.r,
                                      y: blob.y - blob.r,
                                      width: blob.r * 2, height: blob.r * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .radialGradient(
                                Gradient(colors: [blob.c, .clear]),
                                center: CGPoint(x: blob.x, y: blob.y),
                                startRadius: 0, endRadius: blob.r
                             ))
                }
            }
        }
        .ignoresSafeArea()
    }
}
