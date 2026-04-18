import SwiftUI

@main
struct AiMonitorApp: App {
    @StateObject private var sysMonitor = SystemMonitor()
    @StateObject private var svcMonitor = ServiceMonitor()
    @StateObject private var apiServer:  APIServer

    init() {
        let sys = SystemMonitor()
        let svc = ServiceMonitor()
        _sysMonitor = StateObject(wrappedValue: sys)
        _svcMonitor = StateObject(wrappedValue: svc)
        _apiServer  = StateObject(wrappedValue: APIServer(sys: sys, svc: svc))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sysMonitor)
                .environmentObject(svcMonitor)
                .environmentObject(apiServer)
                .onAppear { apiServer.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 840, height: 444)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {
                Link("Ollama Docs",  destination: URL(string: "https://ollama.com")!)
                Link("ComfyUI Docs", destination: URL(string: "https://github.com/comfyanonymous/ComfyUI")!)
                Divider()
                Button("Restart API Server") { apiServer.restart() }
            }
        }
    }
}
