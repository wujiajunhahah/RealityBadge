import Foundation
import UniformTypeIdentifiers
import SwiftUI

// 用于 AppDelegate 将外部传入的文件 URL 转交到 SwiftUI 层
final class RBDocumentOpener {
    static let shared = RBDocumentOpener()
    var handler: ((URL) -> Void)?
}

// App 内部的导入帮助
enum RBBadgeImportHelper {
    static func importPackage(at url: URL, into state: AppState) {
        do {
            let badge = try RBPackage.import(from: url)
            DispatchQueue.main.async {
                state.recentBadges.insert(badge, at: 0)
            }
        } catch {
            print("Failed to import .rbadge: \(error)")
        }
    }
}

// 自定义 UTType：.rbadge
extension UTType {
    static var rbadge: UTType {
        UTType(tag: "rbadge", tagClass: .filenameExtension, conformingTo: .package) ?? .package
    }
}

