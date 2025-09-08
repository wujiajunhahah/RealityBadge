import Foundation
import SwiftUI

// 简单的深链入口（预留）
final class RBDeepLinkOpener {
    static let shared = RBDeepLinkOpener()
    var handler: ((URL) -> Void)?
}

enum RBRouter {
    static func handle(url: URL, state: AppState) {
        guard url.scheme == "rb" else { return }
        let path = url.host ?? ""
        switch path {
        case "capture":
            state.showCapture = true
        case "settings":
            state.showSettings = true
        case "badge":
            if let idStr = url.lastPathComponent.removingPercentEncoding,
               let id = UUID(uuidString: idStr) {
                let all = RBRepository.badges.loadAll()
                if let badge = all.first(where: { $0.id == id }) {
                    state.lastCapturedImage = badge.imagePath.flatMap { UIImage(contentsOfFile: $0) }
                    state.lastSubjectMask = badge.maskPath.flatMap { UIImage(contentsOfFile: $0) }
                    state.lastDepthMap = badge.depthPath.flatMap { UIImage(contentsOfFile: $0) }
                    state.sheet = .badge3DPreview(badge)
                }
            }
        default: break
        }
    }
}

