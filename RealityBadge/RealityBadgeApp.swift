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
                    // Normalize any legacy settings values before UI reads them
                    normalizeLegacySettings()
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

private func normalizeLegacySettings() {
    let defaults = UserDefaults.standard
    // Fix validation mode that may have been stored with Chinese labels
    if let raw = defaults.string(forKey: "rb.validation.mode") {
        let known = Set(RBValidationMode.allCases.map { $0.rawValue })
        if !known.contains(raw) {
            let mapping: [String: String] = [
                "严格（手-物交互）": RBValidationMode.strict.rawValue,
                "标准（物体为主）": RBValidationMode.standard.rawValue,
                "宽松（仅语义匹配）": RBValidationMode.lenient.rawValue
            ]
            if let mapped = mapping[raw] {
                defaults.set(mapped, forKey: "rb.validation.mode")
            } else {
                defaults.set(RBValidationMode.standard.rawValue, forKey: "rb.validation.mode")
            }
        }
    }
}
