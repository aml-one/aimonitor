import SwiftUI

/// Solid dark card container
struct GlassCard<Content: View>: View {
    var accentGlow: Color = .clear
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.15, opacity: 0.72))
            content()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 3)
    }
}
