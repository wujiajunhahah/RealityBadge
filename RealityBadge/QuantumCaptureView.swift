import SwiftUI
import AVFoundation
import Vision

/// 量子扫描界面 - 现代化的徽章生成界面
struct QuantumCaptureView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera: CameraController
    @State private var isCapturing = false
    @State private var capturedImage: UIImage?
    @State private var subjectMask: UIImage?
    @State private var depthMap: UIImage?
    @State private var semanticLabel: String = ""
    @State private var scanPhase: ScanPhase = .initializing
    @State private var particleField: [QuantumParticle] = []
    @State private var gridOffset: CGFloat = 0

    // 扫描阶段枚举
    enum ScanPhase {
        case initializing
        case scanning
        case analyzing
        case synthesizing
        case completed

        var color: Color {
            switch self {
            case .initializing: return Color.blue
            case .scanning: return Color.cyan
            case .analyzing: return Color.purple
            case .synthesizing: return Color.mint
            case .completed: return Color.green
            }
        }

        var description: String {
            switch self {
            case .initializing: return "量子校准中..."
            case .scanning: return "量子扫描中..."
            case .analyzing: return "分析目标结构..."
            case .synthesizing: return "合成量子徽章..."
            case .completed: return "徽章生成完成!"
            }
        }
    }

    // 量子粒子结构
    struct QuantumParticle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var size: CGFloat
        var opacity: Double
        var color: Color
        var life: Double
    }

    init() {
        // 继承原有的目标关键词配置
        let targets: [String] = [
            "screen","display","monitor","tv","laptop","computer",
            "ipad","tablet","iphone","phone","mobile",
            "headphones","earbuds","earphones","airpods","headset",
            "cup","mug","coffee","tumbler","bottle",
            "umbrella",
            "paper","document","doc","sheet","page","notebook","book"
        ]
        let engine = SemanticEngine(targetKeywords: targets)
        let tmpSettings = RBSettings()
        _camera = StateObject(wrappedValue: CameraController(engine: engine, settings: tmpSettings))
    }

    var body: some View {
        ZStack {
            // 背景层
            backgroundView

            // 相机预览层
            cameraPreviewLayer

            // 量子扫描效果层
            quantumEffectsLayer

            // UI控制层
            interfaceLayer
        }
        .onAppear {
            startQuantumEffects()
            updateScanPhase()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: camera.progress) { _, newValue in
            updateScanPhase()
            updateQuantumProgress(progress: newValue)
        }
        .onChange(of: camera.currentScores?.semanticLabel) { _, newLabel in
            if let label = newLabel {
                withAnimation(.easeInOut(duration: 0.5)) {
                    semanticLabel = label
                }
            }
        }
    }

    // MARK: - 背景视图
    @ViewBuilder
    private var backgroundView: some View {
        #if targetEnvironment(simulator)
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.05, blue: 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text("Camera unavailable in Simulator\nRun on a device")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .padding()
        )
        #else
        if camera.isAuthorized {
            Color.black.opacity(0.9)
        } else {
            LinearGradient(
                colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        #endif
    }

    // MARK: - 相机预览层
    @ViewBuilder
    private var cameraPreviewLayer: some View {
        #if targetEnvironment(simulator)
        EmptyView()
        #else
        if camera.isAuthorized {
            CameraPreview(session: camera.session)
                .opacity(0.8)
                .overlay(
                    // 量子网格覆盖
                    QuantumGridView(offset: gridOffset)
                        .opacity(0.3)
                )
        }
        #endif
    }

    // MARK: - 量子效果层
    @ViewBuilder
    private var quantumEffectsLayer: some View {
        ZStack {
            // 扫描波纹
            if scanPhase == .scanning {
                ScanningRippleView(progress: camera.progress, color: scanPhase.color)
                    .opacity(0.6)
            }

            // 粒子场
            ForEach(particleField) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .opacity(particle.opacity)
                    .position(particle.position)
                    .blur(radius: 1)
            }

            // 目标检测框
            if !semanticLabel.isEmpty {
                TargetDetectionFrame(label: semanticLabel, confidence: camera.progress)
            }
        }
    }

    // MARK: - 界面控制层
    @ViewBuilder
    private var interfaceLayer: some View {
        VStack {
            // 顶部控制栏
            topControlBar

            Spacer()

            // 中央扫描区域
            centralScanArea

            Spacer()

            // 底部状态和进度
            bottomStatusArea
        }
    }

    // MARK: - 顶部控制栏
    @ViewBuilder
    private var topControlBar: some View {
        HStack {
            Button { dismiss() } label: {
                QuantumBackButton()
            }

            Spacer()

            // 扫描状态指示器
            ScanStatusIndicator(phase: scanPhase, progress: camera.progress)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - 中央扫描区域
    @ViewBuilder
    private var centralScanArea: some View {
        ZStack {
            // 六边形扫描框
            HexagonScanFrame(
                isActive: camera.isAuthorized,
                progress: camera.progress,
                phase: scanPhase
            )

            // 中央信息显示
            VStack(spacing: 12) {
                if !semanticLabel.isEmpty {
                    QuantumLabelView(label: semanticLabel, confidence: camera.progress)
                }

                Text(scanPhase.description)
                    .font(.system(.title2, design: .rounded, weight: .medium))
                    .foregroundStyle(scanPhase.color)
                    .opacity(0.9)
            }
        }
        .frame(height: 300)
    }

    // MARK: - 底部状态区域
    @ViewBuilder
    private var bottomStatusArea: some View {
        VStack(spacing: 20) {
            // 数据分析面板
            DataAnalysisPanel(scores: camera.currentScores)

            // 六边形进度系统
            HexagonProgressSystem(
                progress: camera.progress,
                phase: scanPhase,
                onCapture: { triggerQuantumCapture() }
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }

    // MARK: - 量子捕获逻辑
    private func triggerQuantumCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        RBHaptics.success()

        // 触发捕获
        camera.capturePhoto()

        let title = semanticLabel.isEmpty ? "量子物体" : semanticLabel
        let symbol = getSymbolForObject(title)

        let new = Badge(
            title: title,
            date: .now,
            style: "quantum",
            done: true,
            symbol: symbol
        )

        // 量子合成动画阶段
        scanPhase = .synthesizing

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let capturedImage = self.camera.capturedFrame {
                self.state.lastCapturedImage = capturedImage
                self.state.lastSubjectMask = self.camera.capturedSubjectMask ?? self.subjectMask
                self.state.lastDepthMap = self.camera.capturedDepthMap ?? self.depthMap
            }

            self.camera.stop()
            self.scanPhase = .completed

            // 延迟显示3D预览
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.state.sheet = .badge3DPreview(new)
                self.isCapturing = false
                self.camera.progress = 0
            }
        }
    }

    // MARK: - 辅助方法
    private func updateScanPhase() {
        let progress = camera.progress

        if progress < 0.2 {
            scanPhase = .initializing
        } else if progress < 0.6 {
            scanPhase = .scanning
        } else if progress < 0.9 {
            scanPhase = .analyzing
        } else if progress < 1.0 {
            scanPhase = .synthesizing
        } else {
            scanPhase = .completed
        }
    }

    private func startQuantumEffects() {
        // 初始化粒子场
        regenerateParticleField()

        // 启动网格动画
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            gridOffset = 100
        }

        // 启动粒子动画
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateParticleField()
        }
    }

    private func regenerateParticleField() {
        let count = UIDevice.current.userInterfaceIdiom == .pad ? 40 : 25
        particleField = (0..<count).map { _ in
            QuantumParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -2...2),
                    dy: CGFloat.random(in: -3...1)
                ),
                size: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.3...0.8),
                color: [Color.cyan, Color.mint, Color.purple, Color.blue].randomElement() ?? Color.cyan,
                life: Double.random(in: 0.5...1.0)
            )
        }
    }

    private func updateParticleField() {
        particleField = particleField.map { particle in
            var updated = particle
            updated.position.x += updated.velocity.dx
            updated.position.y += updated.velocity.dy
            updated.life -= 0.01
            updated.opacity = particle.opacity * updated.life

            // 重置离开屏幕或生命结束的粒子
            if updated.position.y < -10 || updated.life <= 0 {
                updated.position.y = UIScreen.main.bounds.height + 10
                updated.position.x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
                updated.life = 1.0
                updated.opacity = Double.random(in: 0.3...0.8)
            }

            return updated
        }
    }

    private func updateQuantumProgress(progress: CGFloat) {
        // 根据进度调整粒子密度和速度
        let intensity = Double(progress)
        let boost = 1.0 + intensity * 2.0

        particleField = particleField.map { particle in
            var updated = particle
            updated.velocity = CGVector(
                dx: particle.velocity.dx * boost,
                dy: particle.velocity.dy * boost
            )
            updated.color = scanPhase.color
            return updated
        }

        // 触觉反馈
        if progress > 0.3 && progress < 0.35 {
            HapticEngine.shared.quantumPhase(phase: 1)
        } else if progress > 0.6 && progress < 0.65 {
            HapticEngine.shared.quantumPhase(phase: 2)
        } else if progress > 0.9 && progress < 0.95 {
            HapticEngine.shared.quantumPhase(phase: 3)
        }
    }

    private func getSymbolForObject(_ object: String) -> String {
        let s = object.lowercased()
        // 继承原有的符号映射逻辑
        if s.contains("ipad") || s.contains("tablet") { return "ipad" }
        if s.contains("iphone") || s.contains("phone") || s.contains("mobile") { return "iphone" }
        if s.contains("screen") || s.contains("display") || s.contains("monitor") || s.contains("tv") { return "display" }
        if s.contains("headphone") || s.contains("headset") || s.contains("earbud") || s.contains("earphone") || s.contains("airpods") { return "headphones" }
        if s.contains("cup") || s.contains("mug") || s.contains("tumbler") || s.contains("bottle") || s.contains("coffee") { return "cup.and.saucer" }
        if s.contains("umbrella") { return "umbrella" }
        if s.contains("paper") || s.contains("document") || s.contains("doc") || s.contains("sheet") || s.contains("page") { return "doc.text" }
        if s.contains("book") || s.contains("notebook") { return "book" }

        let cnMap: [String: String] = [
            "树木": "tree", "咖啡杯": "cup.and.saucer", "雨伞": "umbrella",
            "手机": "iphone", "书本": "book", "花朵": "leaf", "钥匙": "key", "眼镜": "eyeglasses"
        ]
        if let m = cnMap[object] { return m }
        return "questionmark.circle"
    }
}

// MARK: - 量子组件视图
struct QuantumBackButton: View {
    var body: some View {
        Image(systemName: "chevron.backward")
            .font(.system(size: 18, weight: .semibold))
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                    )
            )
            .foregroundStyle(.white)
    }
}

struct ScanStatusIndicator: View {
    let phase: QuantumCaptureView.ScanPhase
    let progress: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(phase.color)
                .frame(width: 8, height: 8)
                .scaleEffect(phase == .completed ? 1.5 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: phase)

            Text("\(Int(progress * 100))%")
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(phase.color.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

struct QuantumGridView: View {
    let offset: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let gridSize: CGFloat = 30
            let cols = Int(geometry.size.width / gridSize)
            let rows = Int(geometry.size.height / gridSize)

            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<cols, id: \.self) { col in
                    Rectangle()
                        .fill(Color.cyan.opacity(0.3))
                        .frame(width: 1, height: gridSize * 0.8)
                        .position(
                            x: CGFloat(col) * gridSize + gridSize/2 + ((row % 2) == 0 ? offset : 0),
                            y: CGFloat(row) * gridSize + gridSize/2
                        )
                }
            }
        }
    }
}

struct ScanningRippleView: View {
    let progress: CGFloat
    let color: Color
    @State private var animationPhase: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(0.6), lineWidth: 2)
                    .scaleEffect(1 + animationPhase + CGFloat(index) * 0.3)
                    .opacity(1.0 - animationPhase - CGFloat(index) * 0.3)
            }
        }
        .frame(width: 200, height: 200)
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                animationPhase = 1.5
            }
        }
    }
}

struct TargetDetectionFrame: View {
    let label: String
    let confidence: CGFloat
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 8) {
            // 检测框
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.mint.opacity(0.8), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.mint.opacity(0.1))
                )
                .frame(width: 120, height: 80)
                .scaleEffect(pulseScale)
                .overlay(
                    // 角标
                    VStack {
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.mint)
                                .frame(width: 12, height: 4)
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.mint)
                                .frame(width: 12, height: 4)
                        }
                        Spacer()
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.mint)
                                .frame(width: 12, height: 4)
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.mint)
                                .frame(width: 12, height: 4)
                        }
                    }
                )

            // 标签
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.mint.opacity(0.8))
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }
}

struct QuantumLabelView: View {
    let label: String
    let confidence: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.cyan)

            Text(label)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("• \(Int(confidence * 100))%")
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan, Color.mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
    }
}

struct HexagonScanFrame: View {
    let isActive: Bool
    let progress: CGFloat
    let phase: QuantumCaptureView.ScanPhase
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // 外层六边形
            HexagonShape()
                .stroke(phase.color.opacity(0.6), lineWidth: 3)
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(rotation))

            // 内层六边形
            HexagonShape()
                .stroke(phase.color.opacity(0.4), lineWidth: 2)
                .frame(width: 170, height: 170)
                .rotationEffect(.degrees(-rotation))

            // 扫描线
            if isActive {
                HexagonShape()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [phase.color, Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 185, height: 185)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct DataAnalysisPanel: View {
    let scores: SemanticScores?

    var body: some View {
        HStack(spacing: 12) {
            AnalysisIndicator(
                title: "物体检测",
                value: scores?.objectConfidence ?? 0,
                color: Color.cyan
            )

            AnalysisIndicator(
                title: "手势交互",
                value: scores?.handObjectIoU ?? 0,
                color: Color.mint
            )

            AnalysisIndicator(
                title: "语义匹配",
                value: scores?.textImageSimilarity ?? 0,
                color: Color.purple
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct AnalysisIndicator: View {
    let title: String
    let value: CGFloat
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            CircularProgress(value: value, color: color)
                .frame(width: 24, height: 24)

            Text("\(Int(value * 100))%")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

struct CircularProgress: View {
    let value: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 24, height: 24)

            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(-90))
        }
    }
}

struct HexagonProgressSystem: View {
    let progress: CGFloat
    let phase: QuantumCaptureView.ScanPhase
    let onCapture: () -> Void

    var body: some View {
        ZStack {
            // 背景六边形
            HexagonShape()
                .stroke(Color.white.opacity(0.2), lineWidth: 8)
                .frame(width: 120, height: 120)

            // 进度六边形
            HexagonShape()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [phase.color, phase.color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)

            // 中心按钮
            centerButton
        }
    }

    @ViewBuilder
    private var centerButton: some View {
        if progress >= 1.0 {
            Button(action: onCapture) {
                HexagonShape()
                    .fill(phase.color)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .onAppear {
                HapticEngine.shared.quantumComplete()
            }
        } else if progress >= 0.9 {
            Button(action: onCapture) {
                HexagonShape()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text("创建")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        } else {
            HexagonShape()
                .fill(Color.white.opacity(0.05))
                .frame(width: 60, height: 60)
                .overlay(
                    Text("\(Int(progress * 100))%")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                )
        }
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 - .pi / 2
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - 扩展触觉引擎
extension HapticEngine {
    static func quantumPhase(phase: Int) {
        switch phase {
        case 1:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case 2:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case 3:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        default:
            break
        }
    }

    static func quantumComplete() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}