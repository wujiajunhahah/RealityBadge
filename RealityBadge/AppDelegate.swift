import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.pathExtension.lowercased() == "rbadge" {
            RBDocumentOpener.shared.handler?(url)
            return true
        } else {
            RBDeepLinkOpener.shared.handler?(url)
            return true
        }
    }
}
