import Foundation
import SwiftUI
import UIKit
import CoreMotion

enum RBMode: String, CaseIterable, Identifiable {
    case discover = "寻找新词"
    case daily    = "今日挑战"
    case trends   = "当前热点"
    case saved    = "我的收藏"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .discover: return "拍任何东西，生成新词条"
        case .daily:    return "系统推送的每日一题"
        case .trends:   return "结合节日/天气的动态主题"
        case .saved:    return "你保存的待收集词条"
        }
    }
    var symbol: String {
        switch self {
        case .discover: return "aperture"
        case .daily:    return "sun.min"
        case .trends:   return "sparkles"
        case .saved:    return "bookmark"
        }
    }
}

struct Badge: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let date: Date
    let style: String   // "embossed" / "film" / "pixel"
    let done: Bool
    let symbol: String  // SF Symbol placeholder
}

// MARK: - Settings & Haptics
struct RBSettings {
    @AppStorage("rb.style") var style: String = "embossed"
    @AppStorage("rb.enableParallax") var enableParallax: Bool = true
    @AppStorage("rb.push.freq") var pushFreq: Int = 1
    @AppStorage("rb.validation.mode") var validationModeRaw: String = RBValidationMode.standard.rawValue
    var validationMode: RBValidationMode {
        get { RBValidationMode(rawValue: validationModeRaw) ?? .standard }
        set { validationModeRaw = newValue.rawValue }
    }
}

enum RBHaptics {
    static func light()  { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success(){ UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Motion manager for parallax
final class RBMotion: ObservableObject {
    static let shared = RBMotion()
    private let mgr = CMMotionManager()
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    func start() {
        guard mgr.isDeviceMotionAvailable else { return }
        mgr.deviceMotionUpdateInterval = 1.0/60.0
        mgr.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let d = data else { return }
            self?.roll = d.attitude.roll
            self?.pitch = d.attitude.pitch
        }
    }
    func stop() { mgr.stopDeviceMotionUpdates() }
}

final class AppState: ObservableObject {
    @Published var mode: RBMode = .discover
    @Published var recentBadges: [Badge] = [
        .init(title: "大树", date: .now, style: "embossed", done: true, symbol: "tree"),
        .init(title: "咖啡杯", date: .now.addingTimeInterval(-86400.0*3), style: "film", done: true, symbol: "cup.and.saucer"),
        .init(title: "雨伞", date: .now.addingTimeInterval(-86400.0*10), style: "pixel", done: false, symbol: "umbrella")
    ]
    @Published var showSettings = false
    @Published var showCapture = false
    @Published var sheet: SheetRoute?
    
    // 存储最近捕获的图像数据
    @Published var lastCapturedImage: UIImage?
    @Published var lastSubjectMask: UIImage?
    @Published var lastDepthMap: UIImage?

    // Shared settings accessible via @AppStorage
    let settings = RBSettings()

    enum SheetRoute: Identifiable {
        case importChallenge(title: String, hint: String)
        case badgePreview(Badge)
        case badge3DPreview(Badge)
        var id: String {
            switch self {
            case .importChallenge: return "import"
            case .badgePreview:    return "preview"
            case .badge3DPreview:  return "3dpreview"
            }
        }
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

struct RBColors {
    static let green = Color(hex: "#34C759")
}

// MARK: - Validation Mode
enum RBValidationMode: String, CaseIterable, Identifiable {
    case strict = "严格（手-物互动）"
    case standard = "标准（识别物体）"
    case lenient = "宽松（仅语义匹配）"
    var id: String { rawValue }
}

// MARK: - 性能优化配置
struct PerformanceConfig {
    static let maxImageSize: CGFloat = 1920
    static let thumbnailSize: CGFloat = 200
    static let particleCount: Int = UIDevice.current.userInterfaceIdiom == .pad ? 30 : 20
    static let animationDuration: Double = UIDevice.current.userInterfaceIdiom == .pad ? 2.0 : 1.5
    static let enableComplexEffects: Bool = {
        // 检查设备性能
        let deviceModel = UIDevice.current.model
        let processInfo = ProcessInfo.processInfo
        return processInfo.physicalMemory > 3_000_000_000 // 3GB以上内存
    }()
}