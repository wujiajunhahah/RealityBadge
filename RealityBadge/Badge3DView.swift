import SwiftUI
import CoreMotion

/// 3D徽章展示视图 - 支持iPhone和iPad的动态适配
struct Badge3DView: View {
    let badge: Badge
    let capturedImage: UIImage?
    let subjectMask: UIImage?
    let depthMap: UIImage?
    
    @StateObject private var motionManager = MotionManager()
    @State private var dragOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    @State private var subjectCutout: UIImage?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // 动态适配尺寸
    private var badgeSize: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            // iPad
            return 300
        } else if horizontalSizeClass == .compact {
            // iPhone 竖屏
            return 240
        } else {
            // iPhone 横屏
            return 200
        }
    }
    
    private var layerSpacing: CGFloat {
        badgeSize * 0.15
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景层
                backgroundLayer
                
                // 3D徽章容器
                badge3DContainer
                    .frame(width: badgeSize, height: badgeSize)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .background(
            LinearGradient(colors: [
                Color(hex: "#F7FBFF"),
                Color(hex: "#F3F8FF")
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .onAppear { 
            motionManager.start()
            updateCutout()
        }
        .onDisappear { motionManager.stop() }
        .onChange(of: motionManager.roll) { _, _ in
            let inten = min(1.0, max(0, abs(motionManager.roll) + abs(motionManager.pitch)) / 1.5)
            HapticEngine.shared.dynamicShake(intensity: Float(inten))
        }
        .onChange(of: subjectMask) { _, _ in updateCutout() }
        .onChange(of: capturedImage) { _, _ in updateCutout() }
    }
    
    private var backgroundLayer: some View {
        ZStack {
            // 动态背景
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 20)
                    .opacity(0.3)
                    .ignoresSafeArea()
            } else {
                LinearGradient(colors: [Color(hex: "#EAF7FF"), Color(hex: "#EDEBFE")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            
            // 粒子效果
            ParticleField()
                .opacity(0.5)
        }
    }
    
    private var badge3DContainer: some View {
        ZStack {
            // 计算3D变换
            let totalOffsetX = dragOffset.width + accumulatedOffset.width + motionManager.roll * 30
            let totalOffsetY = dragOffset.height + accumulatedOffset.height + motionManager.pitch * 30
            
            let rotationX = totalOffsetY / 10
            let rotationY = -totalOffsetX / 10
            
            // 背景层 - 环境照片
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: badgeSize, height: badgeSize)
                    .clipShape(RoundedRectangle(cornerRadius: badgeSize * 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: badgeSize * 0.1)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .rotation3DEffect(
                        .degrees(rotationX * 0.3),
                        axis: (x: 1, y: 0, z: 0)
                    )
                    .rotation3DEffect(
                        .degrees(rotationY * 0.3),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .offset(
                        x: -totalOffsetX * 0.05,
                        y: -totalOffsetY * 0.05
                    )
                    .blur(radius: 2)
                    .opacity(0.7)
            }
            
            // 主体层 - 使用蒙版从原图裁剪出的主体
            if let subject = subjectCutout {
                Image(uiImage: subject)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: badgeSize * 0.8, height: badgeSize * 0.8)
                    .rotation3DEffect(
                        .degrees(rotationX * 0.6),
                        axis: (x: 1, y: 0, z: 0)
                    )
                    .rotation3DEffect(
                        .degrees(rotationY * 0.6),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .offset(
                        x: -totalOffsetX * 0.1,
                        y: -totalOffsetY * 0.1
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 5, y: 5)
            }
            
            // 前景层 - 徽章信息
            badgeInfoLayer
                .rotation3DEffect(
                    .degrees(rotationX),
                    axis: (x: 1, y: 0, z: 0)
                )
                .rotation3DEffect(
                    .degrees(rotationY),
                    axis: (x: 0, y: 1, z: 0)
                )
                .offset(
                    x: -totalOffsetX * 0.15,
                    y: -totalOffsetY * 0.15
                )
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    // 动态触觉反馈
                    let intensity = min(1.0, sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2)) / 100)
                    HapticEngine.shared.interact3D(intensity: Float(intensity))
                }
                .onEnded { _ in
                    accumulatedOffset.width += dragOffset.width
                    accumulatedOffset.height += dragOffset.height
                    dragOffset = .zero
                    HapticEngine.shared.liquidTransition()
                }
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: dragOffset)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: motionManager.roll)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: motionManager.pitch)
    }
    
    private var badgeInfoLayer: some View {
        VStack(spacing: badgeSize * 0.04) {
            // 徽章图标
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: badgeSize * 0.3, height: badgeSize * 0.3)
                
                Image(systemName: badge.symbol)
                    .font(.system(size: badgeSize * 0.15, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            .shadow(color: .white.opacity(0.5), radius: 10)
            
            // 徽章标题
            Text(badge.title)
                .font(.system(size: badgeSize * 0.08, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
            
            // 获得日期
            Text(dateString(badge.date))
                .font(.system(size: badgeSize * 0.05, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
        }
        .padding(badgeSize * 0.08)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: badgeSize * 0.08)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)
                // 液态玻璃高光
                if #available(iOS 16.0, *) {
                    LiquidGlassView(opacity: 0.25, blur: 12)
                        .clipShape(RoundedRectangle(cornerRadius: badgeSize * 0.08))
                }
            }
        )
    }
}

/// 陀螺仪管理器
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var yaw: Double = 0
    
    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }
            
            // 使用低通滤波器平滑数据
            let alpha = 0.8
            self?.pitch = alpha * (self?.pitch ?? 0) + (1 - alpha) * motion.attitude.pitch
            self?.roll = alpha * (self?.roll ?? 0) + (1 - alpha) * motion.attitude.roll
            self?.yaw = alpha * (self?.yaw ?? 0) + (1 - alpha) * motion.attitude.yaw
        }
    }
    
    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}

private extension Badge3DView {
    func updateCutout() {
        guard let img = capturedImage, let m = subjectMask else {
            subjectCutout = nil
            return
        }
        subjectCutout = RBMakeSubjectCutout(image: img, mask: m)
    }
}

/// 粒子场景效果
struct ParticleField: View {
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var speed: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                Circle()
                    .fill(Color.white)
                    .frame(width: particle.size, height: particle.size)
                    .opacity(particle.opacity)
                    .position(x: particle.x, y: particle.y)
            }
            .onAppear {
                createParticles(in: geometry.size)
                animateParticles()
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let count = PerformanceConfig.particleCount
        particles = (0..<count).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.1...0.3),
                speed: Double.random(in: 10...30)
            )
        }
    }
    
    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear) {
                particles = particles.map { particle in
                    var p = particle
                    p.y -= CGFloat(p.speed)
                    if p.y < -10 {
                        p.y = UIScreen.main.bounds.height + 10
                        p.x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
                    }
                    return p
                }
            }
        }
    }
}
