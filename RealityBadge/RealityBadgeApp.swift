import SwiftUI

@main
struct RealityBadgeApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
        }
    }
}