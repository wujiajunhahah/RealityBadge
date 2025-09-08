import SwiftUI

@main
struct RealityBadgeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                    // 将文档打开回调绑定到当前 AppState
                    RBDocumentOpener.shared.handler = { url in
                        RBBadgeImportHelper.importPackage(at: url, into: appState)
                    }
                    RBDeepLinkOpener.shared.handler = { url in
                        RBRouter.handle(url: url, state: appState)
                    }
                    // 加载本地已保存徽章（如有则覆盖默认示例）
                    let existing = RBRepository.badges.loadAll()
                    if !existing.isEmpty {
                        appState.recentBadges = existing
                    }
                }
        }
    }
}
