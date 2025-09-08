import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans
    case en
    var id: String { rawValue }
}

enum RBStringKey: String {
    case appTitle
    case startExploring
    case badgeLibrary
    case viewAll
    case createNow
    case previewMode
    case card3D
    case ar
    case immersive
    case saveToLibrary
    case share
    case `continue`
    case detected
    case alignAndHold
    case cameraPermissionRequired
}

struct RBStrings {
    static func currentLanguage() -> AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "rb.language") ?? AppLanguage.system.rawValue
        let lang = AppLanguage(rawValue: raw) ?? .system
        if lang == .system {
            let first = Locale.preferredLanguages.first?.lowercased() ?? "en"
            if first.hasPrefix("zh") { return .zhHans }
            return .en
        }
        return lang
    }

    static func t(_ key: RBStringKey) -> String {
        switch currentLanguage() {
        case .zhHans:
            return zh[key] ?? en[key] ?? key.rawValue
        case .en:
            fallthrough
        case .system:
            return en[key] ?? key.rawValue
        }
    }

    private static let en: [RBStringKey: String] = [
        .appTitle: "Reality Badges",
        .startExploring: "Start Exploring",
        .badgeLibrary: "Badge Library",
        .viewAll: "View All",
        .createNow: "Create Now",
        .previewMode: "Preview Mode",
        .card3D: "3D Card",
        .ar: "AR",
        .immersive: "Immersive",
        .saveToLibrary: "Save to Library",
        .share: "Share",
        .continue: "Continue",
        .detected: "Detected",
        .alignAndHold: "Align object and hold steady",
        .cameraPermissionRequired: "Camera permission required"
    ]

    private static let zh: [RBStringKey: String] = [
        .appTitle: "Reality 徽章",
        .startExploring: "开始探索",
        .badgeLibrary: "徽章库",
        .viewAll: "查看全部",
        .createNow: "立即创建",
        .previewMode: "预览模式",
        .card3D: "3D 卡片",
        .ar: "AR",
        .immersive: "沉浸",
        .saveToLibrary: "保存到库中",
        .share: "分享",
        .continue: "继续",
        .detected: "识别到",
        .alignAndHold: "对齐物体并保持稳定",
        .cameraPermissionRequired: "需要相机权限"
    ]
}

