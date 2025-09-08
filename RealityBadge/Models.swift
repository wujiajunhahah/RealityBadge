import Foundation
import SwiftUI
import UIKit
import CoreMotion

enum RBMode: String, CaseIterable, Identifiable {
    case discover = "Discover"
    case daily    = "Daily Challenge"
    case trends   = "Trends"
    case saved    = "Saved"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .discover: return "Point at anything to create a badge"
        case .daily:    return "One prompt every day"
        case .trends:   return "Seasonal and trending topics"
        case .saved:    return "Your saved prompts"
        }
    }
    var symbol: String {
        switch self {
        case .discover: return "camera.aperture"
        case .daily:    return "sun.min"
        case .trends:   return "sparkles"
        case .saved:    return "bookmark"
        }
    }
}

// 全局常量（可用于版本演进等）
struct RBConstants {
    static let schemaVersion = 1
}

struct Badge: Identifiable, Hashable {
    // 数据结构版本，便于将来迁移
    let schemaVersion: Int
    let id: UUID
    let title: String
    let date: Date
    let style: String   // "embossed" / "film" / "pixel"
    let done: Bool
    let symbol: String  // SF Symbol placeholder
    // 可选：与该徽章关联的资源（磁盘路径）
    let imagePath: String?
    let maskPath: String?
    let depthPath: String?

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        style: String,
        done: Bool,
        symbol: String,
        imagePath: String? = nil,
        maskPath: String? = nil,
        depthPath: String? = nil,
        schemaVersion: Int = RBConstants.schemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.date = date
        self.style = style
        self.done = done
        self.symbol = symbol
        self.imagePath = imagePath
        self.maskPath = maskPath
        self.depthPath = depthPath
    }
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
    @Published var shake: Double = 0
    func start() {
        guard mgr.isDeviceMotionAvailable else { return }
        mgr.deviceMotionUpdateInterval = 1.0/60.0
        mgr.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let d = data else { return }
            self?.roll = d.attitude.roll
            self?.pitch = d.attitude.pitch
            // 基于 userAcceleration 估算“摇晃强度” 0...1（带低通）
            let ax = d.userAcceleration.x
            let ay = d.userAcceleration.y
            let az = d.userAcceleration.z
            let magnitude = sqrt(ax*ax + ay*ay + az*az) // 约 0..3g
            let normalized = min(1.0, magnitude / 1.5)
            // 简单低通滤波
            let alpha = 0.2
            self?.shake = alpha * normalized + (1 - alpha) * (self?.shake ?? 0)
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
    case strict = "Strict (hand-object)"
    case standard = "Standard (object)"
    case lenient = "Lenient (semantic only)"
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

// MARK: - Feature Flags（本地 JSON / 远端占位）
struct FeatureFlags: Codable {
    var newBadgeEnabled: Bool
    var onlineFeaturesEnabled: Bool
    var notificationsUIEnabled: Bool

    static let `default` = FeatureFlags(
        newBadgeEnabled: false,
        onlineFeaturesEnabled: false,
        notificationsUIEnabled: false
    )

    static func loadFromBundle() -> FeatureFlags {
        if let url = Bundle.main.url(forResource: "feature_flags", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let flags = try? JSONDecoder().decode(FeatureFlags.self, from: data) {
            return flags
        }
        return .default
    }
}

final class FeatureFlagsManager: ObservableObject {
    static let shared = FeatureFlagsManager()
    @Published private(set) var flags: FeatureFlags
    private init() { self.flags = FeatureFlags.loadFromBundle() }
    func override(with flags: FeatureFlags) { self.flags = flags }
}

// MARK: - 服务抽象（Push / Backend 预留协议 + Noop 实现）
protocol RBBackendService {
    func fetchRemoteConfig(completion: @escaping (FeatureFlags) -> Void)
    func uploadBadge(_ badge: Badge, completion: @escaping (Result<Void, Error>) -> Void)
}

protocol RBPushService {
    func requestAuthorization(completion: @escaping (Bool) -> Void)
    func scheduleDailyChallenge(time: Date, frequencyPerWeek: Int)
    func cancelAll()
}

struct RBNoopBackendService: RBBackendService {
    func fetchRemoteConfig(completion: @escaping (FeatureFlags) -> Void) { completion(.default) }
    func uploadBadge(_ badge: Badge, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

struct RBNoopPushService: RBPushService {
    func requestAuthorization(completion: @escaping (Bool) -> Void) { completion(false) }
    func scheduleDailyChallenge(time: Date, frequencyPerWeek: Int) { /* no-op */ }
    func cancelAll() { /* no-op */ }
}

enum RBServices {
    static var backend: RBBackendService = RBNoopBackendService()
    static var push: RBPushService = RBNoopPushService()
    static var auth: RBAuthService = RBNoopAuthService()
    static var purchase: RBPurchaseService = RBNoopPurchaseService()
}

// MARK: - 资产打包格式（.rbadge）
struct RBBadgeManifest: Codable {
    let schemaVersion: Int
    let id: String
    let title: String
    let dateISO8601: String
    let style: String
    let symbol: String
    let assets: Assets
    struct Assets: Codable { let image: String?; let mask: String?; let depth: String? }
}

enum RBPackage {
    static func export(badge: Badge) throws -> URL {
        let fm = FileManager.default
        let doc = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let safeTitle = badge.title.replacingOccurrences(of: "/", with: "-")
        let pkgName = "\(safeTitle)-\(badge.id.uuidString.prefix(6)).rbadge"
        let pkg = doc.appendingPathComponent(pkgName, isDirectory: true)
        let assetsDir = pkg.appendingPathComponent("assets", isDirectory: true)
        try? fm.removeItem(at: pkg)
        try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        func copy(_ path: String?, as name: String) -> String? {
            guard let p = path else { return nil }
            let src = URL(fileURLWithPath: p)
            let dst = assetsDir.appendingPathComponent(name)
            do { try fm.copyItem(at: src, to: dst); return "assets/\(name)" } catch { return nil }
        }
        let imgName = "image.jpg"
        let maskName = "mask.png"
        let depthName = "depth.png"
        let assets = RBBadgeManifest.Assets(
            image: copy(badge.imagePath, as: imgName),
            mask: copy(badge.maskPath, as: maskName),
            depth: copy(badge.depthPath, as: depthName)
        )

        let dateStr = ISO8601DateFormatter().string(from: badge.date)
        let manifest = RBBadgeManifest(
            schemaVersion: badge.schemaVersion,
            id: badge.id.uuidString,
            title: badge.title,
            dateISO8601: dateStr,
            style: badge.style,
            symbol: badge.symbol,
            assets: assets
        )
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: pkg.appendingPathComponent("manifest.json"))
        return pkg
    }

    static func exportAll(_ badges: [Badge]) throws -> URL {
        let fm = FileManager.default
        let doc = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = doc.appendingPathComponent("RealityBadge-Export-" + ISO8601DateFormatter().string(from: .now))
        try? fm.removeItem(at: folder)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for b in badges { let pkg = try export(badge: b); try fm.moveItem(at: pkg, to: folder.appendingPathComponent(pkg.lastPathComponent)) }
        return folder
    }

    static func `import`(from packageURL: URL) throws -> Badge {
        let data = try Data(contentsOf: packageURL.appendingPathComponent("manifest.json"))
        let mf = try JSONDecoder().decode(RBBadgeManifest.self, from: data)
        let id = UUID(uuidString: mf.id) ?? UUID()
        let fm = FileManager.default
        let doc = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let base = doc.appendingPathComponent("Badges/\(id.uuidString)")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        func copy(_ rel: String?) -> String? {
            guard let r = rel else { return nil }
            let src = packageURL.appendingPathComponent(r)
            let dst = base.appendingPathComponent((r as NSString).lastPathComponent)
            do { try fm.copyItem(at: src, to: dst); return dst.path } catch { return nil }
        }
        let imagePath = copy(mf.assets.image)
        let maskPath = copy(mf.assets.mask)
        let depthPath = copy(mf.assets.depth)
        let date = ISO8601DateFormatter().date(from: mf.dateISO8601) ?? .now
        return Badge(
            id: id,
            title: mf.title,
            date: date,
            style: mf.style,
            done: true,
            symbol: mf.symbol,
            imagePath: imagePath,
            maskPath: maskPath,
            depthPath: depthPath,
            schemaVersion: mf.schemaVersion
        )
    }
}
