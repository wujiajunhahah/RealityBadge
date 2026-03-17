import SwiftUI
import AVFoundation
import UIKit

// MARK: - 苹果风格相机界面
// 参考 Apple Camera 和 CapWords 设计

struct AppleCameraView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera: CameraController

    @State private var showFlash = false
    @State private var flashMode: FlashMode = .off

    enum FlashMode: String, CaseIterable {
        case off = "关闭"
        case on = "开启"
        case auto = "自动"

        var icon: String {
            switch self {
            case .off: return "bolt.slash"
            case .on: return "bolt.fill"
            case .auto: return "bolt.badge.automatic.fill"
            }
        }
    }

    init() {
        let targets: [String] = ["screen", "ipad", "headphones", "cup", "umbrella", "paper"]
        let engine = SemanticEngine(targetKeywords: targets)
        let tmpSettings = RBSettings()
        _camera = StateObject(wrappedValue: CameraController(engine: engine, settings: tmpSettings))
    }

    var body: some View {
        ZStack {
            // 黑色背景
            Color.black.ignoresSafeArea()

            // 相机预览
            if camera.isAuthorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .overlay {
                        // 网格线（可选）
                        gridView
                    }
            } else {
                permissionView
            }

            // UI 层
            uiLayer
        }
        .onAppear {
            if camera.isAuthorized {
                camera.start()
            }
        }
        .onDisappear {
            camera.stop()
        }
        .statusBar(hidden: true)
    }

    // MARK: - UI 层
    private var uiLayer: some View {
        VStack {
            // 顶部工具栏（极简）
            topToolbar

            Spacer()

            // 底部控制区
            bottomControls
        }
    }

    // MARK: - 顶部工具栏
    private var topToolbar: some View {
        HStack {
            // 闪光灯
            Button {
                cycleFlashMode()
            } label: {
                Image(systemName: flashMode.icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(showFlash ? Color.white.opacity(0.2) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            // Live Photo（可选）
            Button {
                // TODO: 实现 Live Photo
            } label: {
                Image(systemName: "livephoto")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            // 关闭
            Button {
                camera.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - 底部控制区
    private var bottomControls: some View {
        VStack(spacing: 0) {
            // 模式指示器
            modeIndicator

            // 快门按钮区域
            shutterArea

            // 底部安全区域适配
            Spacer()
                .frame(height: 34)
        }
    }

    // MARK: - 模式指示器
    private var modeIndicator: some View {
        HStack(spacing: 32) {
            // 视频
            Button {
                // TODO: 切换到视频模式
            } label: {
                Image(systemName: "video")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            // 照片（当前激活）
            Image(systemName: "photo.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)

            // 正方形
            Button {
                // TODO: 切换到正方形模式
            } label: {
                Image(systemName: "square")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 24)
    }

    // MARK: - 快门区域
    private var shutterArea: some View {
        HStack(spacing: 0) {
            // 左侧：照片库
            Button {
                // TODO: 打开照片库
            } label: {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.5)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 38, height: 38)
                    }
                    .overlay {
                        // 缩略图
                        if let thumbnail = loadMostRecentPhoto() {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 38, height: 38)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            // 中间：快门按钮
            shutterButton

            Spacer()

            // 右侧：切换相机
            Button {
                // TODO: 切换前后摄像头
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 快门按钮
    private var shutterButton: some View {
        Button {
            capturePhoto()
        } label: {
            ZStack {
                // 外圈（白色，半透明）
                Circle()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 72, height: 72)

                // 进度弧线
                Circle()
                    .trim(from: 0, to: min(camera.progress, 1.0))
                    .stroke(
                        Color(UIColor.systemYellow),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: camera.progress)

                // 内圈（根据状态变化）
                Group {
                    if camera.progress >= 1.0 {
                        // 自动拍摄完成
                        Circle()
                            .fill(Color(UIColor.systemYellow))
                            .frame(width: 64, height: 64)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                    } else {
                        // 正常状态
                        Circle()
                            .fill(Color.white)
                            .frame(width: 64, height: 64)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 网格视图（可选）
    private var gridView: some View {
        VStack {
            // 水平线
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.5))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.5))
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 1)

            // 垂直线
            Path { path in
                path.move(to: CGPoint(x: geometry.size.width * 0.5, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height))
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
    }

    private var geometry: GeometryProxy { GeometryProxy() }

    // MARK: - 权限视图
    private var permissionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("需要相机权限")
                .font(.system(.title3, weight: .semibold))

            Text("请在设置中允许访问相机")
                .font(.system(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBlue))
            .clipShape(Capsule())
        }
        .padding(32)
    }

    // MARK: - 辅助方法
    private func cycleFlashMode() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        }
        withAnimation(.spring()) {
            showFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showFlash = false
            }
        }
    }

    private func capturePhoto() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        camera.capturePhoto()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let image = camera.capturedFrame {
                // 保存徽章
                let newBadge = Badge(
                    title: camera.currentScores?.semanticLabel ?? "新徽章",
                    date: .now,
                    style: .minimal,
                    done: true
                )
                state.recentBadges.append(newBadge)
                RBRepository.badges.save(newBadge)

                // 触觉反馈
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func loadMostRecentPhoto() -> UIImage? {
        // TODO: 实现加载最新照片
        return nil
    }
}

// MARK: - 几何读取包装器
struct GeometryReaderModifier: ViewModifier {
    let action: (GeometryProxy) -> Void

    init(action: @escaping (GeometryProxy) -> Void) {
        self.action = action
    }

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { proxy in
                Color.clear.preference(key: GeometryPreferenceKey.self, value: proxy)
            })
            .onPreferenceChange(GeometryPreferenceKey.self) { proxy in
                action(proxy)
            }
    }
}

private struct GeometryPreferenceKey: PreferenceKey {
    typealias Value = GeometryProxy
    static var defaultValue: GeometryProxy = GeometryProxy(
        // 这里的值会被覆盖，所以不重要
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
}

// MARK: - 简化的权限视图
struct SimplePermissionView: View {
    let onAllow: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("需要相机权限")
                .font(.system(.title3, weight: .semibold))

            Button("允许访问") {
                onAllow()
            }
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBlue))
            .clipShape(Capsule())
        }
        .padding(32)
    }
}

#Preview {
    AppleCameraView()
        .environmentObject(AppState())
}
