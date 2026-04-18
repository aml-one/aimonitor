import SwiftUI
import AppKit

// Grabs the NSWindow so we can tweak properties SwiftUI doesn't expose
private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let window = v.window else { return }
            window.isOpaque = false
            window.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.09, alpha: 0.82)
            window.titlebarAppearsTransparent = true
            // Clear SwiftUI hosting layer so it doesn't paint a solid square over the tinted window
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = CGColor.clear
            window.styleMask.remove(.resizable)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var sys: SystemMonitor
    @EnvironmentObject var svc: ServiceMonitor
    @EnvironmentObject var api: APIServer

    var body: some View {
        DashboardView()
            .frame(width: 840)
            .preferredColorScheme(.dark)
            .background(WindowAccessor())
    }
}

#Preview {
    let sys = SystemMonitor()
    let svc = ServiceMonitor()
    return ContentView()
        .environmentObject(sys)
        .environmentObject(svc)
        .environmentObject(APIServer(sys: sys, svc: svc))
}
