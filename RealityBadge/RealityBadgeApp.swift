import SwiftUI

@main
struct RealityBadgeApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(RBAppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: .rbOpenCapture)) { _ in
                    appState.showCapture = true
                }
        }
    }
}
