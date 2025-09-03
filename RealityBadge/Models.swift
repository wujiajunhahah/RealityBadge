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

    // Shared settings accessible via @AppStorage
    let settings = RBSettings()

    enum SheetRoute: Identifiable {
        case importChallenge(title: String, hint: String)
        case badgePreview(Badge)
        var id: String {
            switch self {
            case .importChallenge: return "import"
            case .badgePreview:    return "preview"
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