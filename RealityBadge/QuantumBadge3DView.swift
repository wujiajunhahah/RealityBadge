import SwiftUI
import CoreMotion

/// 量子3D徽章展示 - 未来感十足的徽章渲染
struct QuantumBadge3DView: View {
    let badge: Badge
    let capturedImage: UIImage?
    let subjectMask: UIImage?
    let depthMap: UIImage?

    @StateObject private var motionManager = QuantumMotionManager()
    @State private var dragOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    @State private var subjectCutout: UIImage?
    @State private var isPulsing = false
    @State private var rotationAngle: Double = 0
    @State private var quantumField: [QuantumFieldParticle] = []
    @State private var glowIntensity: Double = 0.5

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    // 动态适配尺寸
    private var badgeSize: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            return 350 // iPad
        } else if horizontalSizeClass == .compact {
            return 280 // iPhone 竖屏
        } else {
            return 240 // iPhone 横屏
        }
    }

    // 量子场粒子结构
    struct QuantumFieldParticle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var size: CGFloat
        var color: Color
        var opacity: Double
        var energy: Double
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 深空背景
                deepSpaceBackground

                // 量子场效果
                quantumFieldEffect

                // 主徽章容器
                mainBadgeContainer
                    .frame(width: badgeSize, height: badgeSize)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // 装饰性量子环
                quantumRings

                // 信息悬浮层
                floatingInfoLayer
            }
        }
        .onAppear {
            startQuantumEffects()
            updateCutout()
        }
        .onDisappear {
            motionManager.stop()
        }
        .onChange(of: motionManager.rotation) { _, _ in
            updateQuantumResponse()
        }
        .onChange(of: subjectMask) { _, _ in updateCutout() }
        .onChange(of: capturedImage) { _, _ in updateCutout() }
    }

    // MARK: - 深空背景
    @ViewBuilder
    private var deepSpaceBackground: some View {
        ZStack {
            // 渐变背景
            RadialGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color.black
                ],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )

            // 星云效果
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 30)
                    .opacity(0.2)
                    .colorMultiply(Color.cyan.opacity(0.3))
            }

            // 深度星场
            DeepSpaceStarField()
        }
        .ignoresSafeArea()
    }

    // MARK: - 量子场效果
    @ViewBuilder
    private var quantumFieldEffect: some View {
        ForEach(quantumField) { particle in
            Circle()
                .fill(particle.color)
                .frame(width: particle.size, height: particle.size)
                .opacity(particle.opacity * particle.energy)
                .position(particle.position)
                .blur(radius: particle.size / 2)
                .shadow(color: particle.color, radius: particle.size)
        }
    }

    // MARK: - 主徽章容器
    @ViewBuilder
    private var mainBadgeContainer: some View {
        ZStack {
            // 计算3D变换
            let totalOffsetX = dragOffset.width + accumulatedOffset.width + motionManager.rotation.x * 50
            let totalOffsetY = dragOffset.height + accumulatedOffset.height + motionManager.rotation.y * 50

            let rotationX = totalOffsetY / 15
            let rotationY = -totalOffsetX / 15

            // 背景量子层
            quantumBackgroundLayer(
                rotationX: rotationX,
                rotationY: rotationY,
                offsetX: -totalOffsetX * 0.1,
                offsetY: -totalOffsetY * 0.1
            )

            // 主体层
            mainSubjectLayer(
                rotationX: rotationX * 1.5,
                rotationY: rotationY * 1.5,
                offsetX: -totalOffsetX * 0.2,
                offsetY: -totalOffsetY * 0.2
            )

            // 前景量子信息层
            quantumInfoLayer(
                rotationX: rotationX * 2,
                rotationY: rotationY * 2,
                offsetX: -totalOffsetX * 0.3,
                offsetY: -totalOffsetY * 0.3
            )

            // 能量核心
            energyCore
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    let intensity = min(1.0, sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2)) / 150)
                    HapticEngine.shared.interact3D(intensity: Float(intensity))
                    updateQuantumIntensity(intensity: intensity)
                }
                .onEnded { _ in
                    accumulatedOffset.width += dragOffset.width
                    accumulatedOffset.height += dragOffset.height
                    dragOffset = .zero
                    HapticEngine.shared.liquidTransition()

                    // 自动回弹
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                        accumulatedOffset = .zero
                    }
                }
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: dragOffset)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: motionManager.rotation)
    }

    // MARK: - 量子背景层
    @ViewBuilder
    private func quantumBackgroundLayer(
        rotationX: Double,
        rotationY: Double,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> some View {
        ZStack {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: badgeSize, height: badgeSize)
                    .clipShape(HexagonShape())
                    .overlay(
                        HexagonShape()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.6), Color.mint.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .rotation3DEffect(
                        .degrees(rotationX * 0.3),
                        axis: (x: 1, y: 0, z: 0)
                    )
                    .rotation3DEffect(
                        .degrees(rotationY * 0.3),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .offset(x: offsetX, y: offsetY)
                    .blur(radius: 1)
                    .opacity(0.8)
            }
        }
    }

    // MARK: - 主体层
    @ViewBuilder
    private func mainSubjectLayer(
        rotationX: Double,
        rotationY: Double,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> some View {
        ZStack {
            if let subject = subjectCutout {
                Image(uiImage: subject)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: badgeSize * 0.7, height: badgeSize * 0.7)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(glowIntensity),
                                        Color.cyan.opacity(glowIntensity * 0.5),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: badgeSize * 0.4
                                ),
                                lineWidth: 3
                            )
                    )
                    .rotation3DEffect(
                        .degrees(rotationX * 0.6),
                        axis: (x: 1, y: 0, z: 0)
                    )
                    .rotation3DEffect(
                        .degrees(rotationY * 0.6),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .offset(x: offsetX, y: offsetY)
                    .shadow(color: Color.cyan.opacity(0.5), radius: 20, x: 0, y: 0)
                    .scaleEffect(isPulsing ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)
            } else {
                // 默认量子核心
                QuantumCoreView(size: badgeSize * 0.6)
                    .rotation3DEffect(
                        .degrees(rotationX * 0.6),
                        axis: (x: 1, y: 0, z: 0)
                    )
                    .rotation3DEffect(
                        .degrees(rotationY * 0.6),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .offset(x: offsetX, y: offsetY)
            }
        }
    }

    // MARK: - 量子信息层
    @ViewBuilder
    private func quantumInfoLayer(
        rotationX: Double,
        rotationY: Double,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> some View {
        VStack(spacing: badgeSize * 0.05) {
            // 量子图标
            ZStack {
                HexagonShape()
                    .fill(.ultraThinMaterial)
                    .frame(width: badgeSize * 0.25, height: badgeSize * 0.25)
                    .overlay(
                        HexagonShape()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan, Color.mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )

                if let subject = subjectCutout {
                    Image(uiImage: subject)
                        .resizable()
                        .scaledToFill()
                        .frame(width: badgeSize * 0.22, height: badgeSize * 0.22)
                        .clipShape(HexagonShape())
                } else {
                    Image(systemName: badge.symbol)
                        .font(.system(size: badgeSize * 0.12, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan, Color.mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .shadow(color: Color.cyan.opacity(0.5), radius: 15, x: 0, y: 0)

            // 徽章标题
            Text(badge.title)
                .font(.system(size: badgeSize * 0.07, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Color.cyan.opacity(0.8), radius: 3, x: 0, y: 0)

            // 量子日期
            Text(quantumDateString(badge.date))
                .font(.system(size: badgeSize * 0.04, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .shadow(color: Color.cyan.opacity(0.5), radius: 2, x: 0, y: 0)
        }
        .padding(badgeSize * 0.08)
        .background(
            ZStack {
                HexagonShape()
                    .fill(.ultraThinMaterial.opacity(0.9))
                    .overlay(
                        HexagonShape()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.cyan.opacity(0.3),
                                        Color.mint.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )

                // 量子玻璃效果
                if #available(iOS 16.0, *) {
                    LiquidGlassView(opacity: 0.3, blur: 15)
                        .clipShape(HexagonShape())
                }
            }
        )
        .rotation3DEffect(
            .degrees(rotationX),
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(rotationY),
            axis: (x: 0, y: 1, z: 0)
        )
        .offset(x: offsetX, y: offsetY)
    }

    // MARK: - 量子环
    @ViewBuilder
    private var quantumRings: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                HexagonShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.3),
                                Color.mint.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: badgeSize + CGFloat(index * 30), height: badgeSize + CGFloat(index * 30))
                    .rotationEffect(.degrees(rotationAngle + Double(index * 60)))
                    .opacity(0.6 - Double(index) * 0.2)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }

    // MARK: - 能量核心
    @ViewBuilder
    private var energyCore: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(glowIntensity),
                        Color.cyan.opacity(glowIntensity * 0.8),
                        Color.mint.opacity(glowIntensity * 0.4),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: badgeSize * 0.3
                )
            )
            .frame(width: badgeSize * 0.6, height: badgeSize * 0.6)
            .blur(radius: 20)
            .opacity(0.7)
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isPulsing)
    }

    // MARK: - 悬浮信息层
    @ViewBuilder
    private var floatingInfoLayer: some View {
        VStack {
            HStack {
                Spacer()
                QuantumInfoCard(
                    title: "量子状态",
                    content: "稳定",
                    color: Color.green
                )
                .padding(.trailing, 20)
                .padding(.top, 60)
            }
            Spacer()
            HStack {
                QuantumInfoCard(
                    title: "能量等级",
                    content: "\(Int(glowIntensity * 100))%",
                    color: Color.cyan
                )
                .padding(.leading, 20)
                Spacer()
            }
            .padding(.bottom, 60)
        }
    }

    // MARK: - 辅助方法
    private func startQuantumEffects() {
        motionManager.start()
        isPulsing = true
        generateQuantumField()

        // 启动能量脉动
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                glowIntensity = Double.random(in: 0.3...0.8)
            }
        }

        // 更新量子场
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateQuantumField()
        }
    }

    private func generateQuantumField() {
        let count = UIDevice.current.userInterfaceIdiom == .pad ? 50 : 30
        quantumField = (0..<count).map { _ in
            QuantumFieldParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -1...1),
                    dy: CGFloat.random(in: -2...0.5)
                ),
                size: CGFloat.random(in: 1...4),
                color: [Color.cyan, Color.mint, Color.purple, Color.blue].randomElement() ?? Color.cyan,
                opacity: Double.random(in: 0.2...0.6),
                energy: Double.random(in: 0.5...1.0)
            )
        }
    }

    private func updateQuantumField() {
        quantumField = quantumField.map { particle in
            var updated = particle
            updated.position.x += updated.velocity.dx
            updated.position.y += updated.velocity.dy
            updated.energy = 0.5 + 0.5 * sin(Date().timeIntervalSince1970 + Double.random(in: 0...1))

            // 重置离开屏幕的粒子
            if updated.position.y < -10 || updated.position.x < -10 ||
               updated.position.x > UIScreen.main.bounds.width + 10 {
                updated.position = CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: UIScreen.main.bounds.height + 10
                )
                updated.energy = 1.0
            }

            return updated
        }
    }

    private func updateQuantumResponse() {
        let intensity = min(1.0, sqrt(pow(motionManager.rotation.x, 2) + pow(motionManager.rotation.y, 2)) / 2.0)
        HapticEngine.shared.dynamicShake(intensity: Float(intensity))

        // 影响量子场
        let boost = 1.0 + intensity * 3.0
        quantumField = quantumField.map { particle in
            var updated = particle
            updated.velocity = CGVector(
                dx: particle.velocity.dx * boost,
                dy: particle.velocity.dy * boost
            )
            updated.energy = min(1.0, particle.energy + intensity * 0.2)
            return updated
        }
    }

    private func updateQuantumIntensity(intensity: CGFloat) {
        glowIntensity = min(1.0, 0.5 + intensity)
    }

    private func updateCutout() {
        guard let img = capturedImage, let m = subjectMask else {
            subjectCutout = nil
            return
        }
        subjectCutout = RBMakeSubjectCutout(image: img, mask: m)
    }

    private func quantumDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: date)
    }
}

/// 量子运动管理器
class QuantumMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var rotation: SIMD3<Double> = .zero

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 120.0 // 更高的刷新率
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }

            // 增强的低通滤波器
            let alpha = 0.85
            self?.rotation.x = alpha * (self?.rotation.x ?? 0) + (1 - alpha) * motion.attitude.pitch
            self?.rotation.y = alpha * (self?.rotation.y ?? 0) + (1 - alpha) * motion.attitude.roll
            self?.rotation.z = alpha * (self?.rotation.z ?? 0) + (1 - alpha) * motion.attitude.yaw
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}

/// 量子核心视图
struct QuantumCoreView: View {
    let size: CGFloat
    @State private var coreRotation: Double = 0
    @State private var energyPulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            // 外层能量环
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.8),
                                Color.mint.opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: size + CGFloat(index * 10), height: size + CGFloat(index * 10))
                    .rotationEffect(.degrees(coreRotation + Double(index * 30)))
                    .opacity(0.6 - Double(index) * 0.1)
            }

            // 核心
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            Color.cyan,
                            Color.mint,
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(energyPulse)
                .blur(radius: 1)

            // 内部符号
            Image(systemName: "cpu")
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
                coreRotation = 360
            }

            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                energyPulse = 1.1
            }
        }
    }
}

/// 深空星场
struct DeepSpaceStarField: View {
    @State private var stars: [Star] = []

    struct Star: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var brightness: Double
        var twinkleSpeed: Double
    }

    var body: some View {
        GeometryReader { geometry in
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .opacity(star.brightness)
                    .position(x: star.x, y: star.y)
                    .blur(radius: star.size / 2)
            }
            .onAppear {
                generateStars(in: geometry.size)
                animateStars()
            }
        }
    }

    private func generateStars(in size: CGSize) {
        let count = Int(size.width * size.height / 5000)
        stars = (0..<count).map { _ in
            Star(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 0.5...2),
                brightness: Double.random(in: 0.3...1.0),
                twinkleSpeed: Double.random(in: 2...5)
            )
        }
    }

    private func animateStars() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            stars = stars.map { star in
                var updated = star
                updated.brightness = 0.3 + 0.7 * abs(sin(Date().timeIntervalSince1970 / star.twinkleSpeed))
                return updated
            }
        }
    }
}

/// 量子信息卡片
struct QuantumInfoCard: View {
    let title: String
    let content: String
    let color: Color
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text(content)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}