import SwiftUI

@main
struct RealityBadgeApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
                .onAppear {
                    // 预取远端配置（当前为 Noop，本地默认）
                    RBServices.backend.fetchRemoteConfig { flags in
                        FeatureFlagsManager.shared.override(with: flags)
                    }
                }
        }
    }
}
