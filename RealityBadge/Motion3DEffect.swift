import SwiftUI
import CoreMotion
import UIKit

// MARK: - Core Motion 3D 交互管理器
// 使用苹果原生 Core Motion 框架

@available(iOS 13.0, *)
final class MotionManager: ObservableObject {
    @Published var motion: CMDeviceMotion?
    @Published var rotation: SIMD3<Double> = .zero
    @Published var tilt: CGPoint = .zero
    @Published var acceleration: SIMD3<Double> = .zero

    private let motionManager = CMMotionManager()
    private let updateQueue = DispatchQueue(label: "com.realitybadge.motion", qos: .userInteractive)
    private var isRunning = false

    // 平滑参数
    private var rotationSmoothness: Double = 0.85
    private var tiltSmoothness: Double = 0.8

    init() {
        setupMotionManager()
    }

    // MARK: - 设置运动管理器
    private func setupMotionManager() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0  // 60 Hz
        motionManager.showsDeviceMovementDisplay = true
    }

    // MARK: - 启动运动跟踪
    func start() {
        guard !isRunning else { return }
        isRunning = true

        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .mainQueue, withHandler: { [weak self] motion in
                self?.handleMotionUpdate(motion)
            })
        }
    }

    // MARK: - 停止运动跟踪
    func stop() {
        isRunning = false
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - 处理运动更新
    private func handleMotionUpdate(_ motion: CMDeviceMotion) {
        self.motion = motion

        // 获取设备旋转率
        if let rotationRate = motion.attitudeRotationRate {
            // 平滑更新旋转
            rotation.x = smooth(value: rotationRate.x, current: rotation.x, smoothness: rotationSmoothness)
            rotation.y = smooth(value: rotationRate.y, current: rotation.y, smoothness: rotationSmoothness)
            rotation.z = smooth(value: rotationRate.z, current: rotation.z, smoothness: rotationSmoothness)
        }

        // 获取设备倾斜度
        if let gravity = motion.gravity {
            // 计算倾斜角度（弧度转角度）
            let maxTilt: Double = .pi / 4  // 最大 45 度
            let tiltX = clamp(gravity.x, min: -maxTilt, max: maxTilt) / maxTilt
            let tiltY = clamp(gravity.y, min: -maxTilt, max: maxTilt) / maxTilt

            // 平滑更新
            tilt.x = smooth(value: tiltX, current: tilt.x, smoothness: tiltSmoothness)
            tilt.y = smooth(value: tiltY, current: tilt.y, smoothness: tiltSmoothness)
        }

        // 获取加速度
        if let userAccel = motion.userAcceleration {
            acceleration.x = userAccel.x
            acceleration.y = userAccel.y
            acceleration.z = userAccel.z
        }
    }

    // MARK: - 平滑函数
    private func smooth(value: Double, current: Double, smoothness: Double) -> Double {
        return current * smoothness + value * (1.0 - smoothness)
    }

    // MARK: - 辅助方法
    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(max, value))
    }

    // MARK: - 便捷属性

    /// 设备是否支持运动跟踪
    var isAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    /// 设备是否活跃
    var isActive: Bool {
        isRunning
    }
}

// MARK: - 3D 视差效果视图
struct Parallax3DView: View {
    let image: UIImage
    @StateObject private var motion = MotionManager()
    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景（提供深度感）
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                // 图片层（带 3D 效果）
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .offset(
                        x: CGFloat(motion.tilt.x) * 30,
                        y: CGFloat(motion.tilt.y) * 30
                    )
                    .rotation3DEffect(
                        .degrees(Double(motion.rotation.y) * 10),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .center,
                        perspective: 1.2
                    )
                    .animation(.spring(response: 0.3), value: motion.tilt)
            }
            .frame(width: 220, height: 220)
            .onAppear {
                motion.start()
            }
            .onDisappear {
                motion.stop()
            }
        }
    }
}

// MARK: - 交互式徽章视图（带陀螺仪控制）
struct InteractiveBadgeView: View {
    let badge: Badge
    let image: UIImage?

    @StateObject private var motion = MotionManager()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(UIColor.systemBackground),
                                Color(UIColor.secondarySystemBackground)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 3D 徽章层
                Group {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.secondary.opacity(0.2))

                            Image(systemName: badge.symbol)
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 200, height: 200)
                .rotation3DEffect(
                    .degrees(Double(motion.rotation.y) * 15),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 1.0
                )
                .offset(
                    x: CGFloat(motion.tilt.x) * 20,
                    y: CGFloat(motion.tilt.y) * 20
                )
                .animation(.spring(response: 0.2), value: motion.rotation)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                // 信息覆盖层
                VStack {
                    HStack {
                        Text(badge.title)
                            .font(.system(.headline, weight: .semibold))

                        Spacer()

                        Image(systemName: "cube")
                            .font(.system(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()

                    // 运动状态指示
                    if motion.isActive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(UIColor.systemGreen))
                                .frame(width: 6, height: 6)

                            Text("陀螺仪启用")
                                .font(.system(.caption2))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 16)
                    }
                }
                .padding()
            }
            .onAppear {
                motion.start()
            }
            .onDisappear {
                motion.stop()
            }
        }
    }
}

// MARK: - 简化的 3D 视差卡片
struct SimpleParallaxCard: View {
    let icon: String
    let title: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))

                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 48))
                        .foregroundStyle(Color(UIColor.systemBlue))

                    Text(title)
                        .font(.system(.headline, weight: .semibold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 150)
            .rotation3DEffect(
                .degrees(10),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.8
            )
        }
    }
}

// MARK: - 运动可视化视图
struct MotionVisualizationView: View {
    @StateObject private var motion = MotionManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("运动状态")
                .font(.system(.headline))

            // 旋转可视化
            VStack(alignment: .leading, spacing: 8) {
                Text("旋转")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)

                HStack {
                    Text("X:")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                    Text("\(motion.rotation.x, specifier: "%.2f)")
                        .monospaced()
                    Text("Y:")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                    Text("\(motion.rotation.y, specifier: "%.2f)")
                        .monospaced()
                }
            }

            // 倾斜可视化
            VStack(alignment: .leading, spacing: 8) {
                Text("倾斜")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)

                HStack {
                    Circle()
                        .fill(motion.tilt.x > 0.1 ? Color(UIColor.systemGreen) : Color(UIColor.systemGray))
                        .frame(width: 8, height: 8)

                    Circle()
                        .fill(motion.tilt.y > 0.1 ? Color(UIColor.systemGreen) : Color(UIColor.systemGray))
                        .frame(width: 8, height: 8)
                }
            }

            // 状态指示
            HStack {
                Circle()
                    .fill(motion.isActive ? Color(UIColor.systemGreen) : Color(UIColor.systemGray))
                    .frame(width: 8, height: 8)

                Text(motion.isActive ? "运行中" : "已停止")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear {
            motion.start()
        }
        .onDisappear {
            motion.stop()
        }
    }
}

// MARK: - 示例视图
struct MotionExampleView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("3D 交互演示")
                    .font(.system(.title2, weight: .bold))

                // 视差卡片
                SimpleParallaxCard(icon: "star.fill", title: "视差效果")

                // 运动可视化
                MotionVisualizationView()
            }
            .padding()
        }
    }
}

#Preview {
    MotionExampleView()
}
