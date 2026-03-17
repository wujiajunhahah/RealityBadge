import SwiftUI
import AVFoundation
import UIKit

// MARK: - 简化版拍摄界面
// 使用苹果原生设计，移除过度设计

struct SimpleCaptureView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera: CameraController
    @State private var capturedImage: UIImage?
    @State private var showPreview = false

    init() {
        let targets: [String] = ["screen", "ipad", "headphones", "cup", "umbrella", "paper"]
        let engine = SemanticEngine(targetKeywords: targets)
        let tmpSettings = RBSettings()
        _camera = StateObject(wrappedValue: CameraController(engine: engine, settings: tmpSettings))
    }

    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()

            // 相机预览
            if camera.isAuthorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .overlay {
                        // 识别状态
                        if let label = camera.currentScores?.semanticLabel {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    recognitionLabel(label)
                                    Spacer()
                                }
                                .padding(.bottom, 160)
                            }
                        }
                    }
            } else {
                permissionView
            }

            // UI 控制
            VStack {
                // 顶部栏
                HStack {
                    Button {
                        camera.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Button {
                        // TODO: 闪光灯切换
                    } label: {
                        Image(systemName: "bolt.slash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                // 底部控制
                bottomControls
            }
        }
        .onAppear {
            if camera.isAuthorized {
                camera.start()
            }
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: capturedImage) { _, newImage in
            if let _ = newImage {
                showPreview = true
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            SimplePreviewView(image: capturedImage) {
                dismiss()
            }
        }
    }

    // MARK: - 权限视图
    private var permissionView: some View {
        VStack(spacing: 20) {
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

    // MARK: - 识别标签
    private func recognitionLabel(_ label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(camera.progress >= 1 ? Color(UIColor.systemGreen) : Color(UIColor.systemBlue))
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - 底部控制
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // 模式选择
            HStack(spacing: 20) {
                ForEach(["自动", "方形", "照片"], id: \.self) { mode in
                    Button {
                        // TODO: 模式切换
                    } label: {
                        Text(mode)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            // 快门按钮
            Button {
                capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 72, height: 72)

                    // 进度弧
                    Circle()
                        .trim(from: 0, to: camera.progress)
                        .stroke(
                            LinearGradient(
                                colors: [Color(UIColor.systemGreen), Color(UIColor.systemBlue)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.3), value: camera.progress)

                    // 快门按钮
                    Circle()
                        .fill(camera.progress >= 1 ? Color(UIColor.systemGreen) : .white)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: camera.progress >= 1 ? "checkmark" : "camera.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(camera.progress >= 1 ? .white : .black)
                        }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 34)
    }

    // MARK: - 拍照
    private func capturePhoto() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        camera.capturePhoto()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let image = camera.capturedFrame {
                self.capturedImage = image
            }
        }
    }
}

// MARK: - 简化版预览界面
struct SimplePreviewView: View {
    let image: UIImage?
    let onDismiss: () -> Void

    @State private var showSuccess = false

    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()

            // 图片
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            }

            // UI 层
            VStack {
                // 顶部栏
                HStack {
                    Button("重拍") {
                        onDismiss()
                    }
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.white)

                    Spacer()

                    if showSuccess {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(UIColor.systemGreen))
                            Text("已保存")
                                .font(.system(.body, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    Button("完成") {
                        saveAndDismiss()
                    }
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Color(UIColor.systemBlue))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                // 底部操作
                HStack(spacing: 16) {
                    PreviewActionButton(icon: "arrow.uturn.backward", title: "重拍") {
                        onDismiss()
                    }

                    Spacer()

                    PreviewActionButton(icon: "square.and.arrow.down", title: "保存", isPrimary: true) {
                        saveAndDismiss()
                    }

                    Spacer()

                    PreviewActionButton(icon: "square.and.arrow.up", title: "分享") {
                        shareImage()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
    }

    private func saveAndDismiss() {
        withAnimation(.spring()) {
            showSuccess = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // TODO: 实际保存逻辑
            onDismiss()
        }
    }

    private func shareImage() {
        // TODO: 实现分享
    }
}

// MARK: - 预览操作按钮
struct PreviewActionButton: View {
    let icon: String
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    init(icon: String, title: String, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isPrimary = isPrimary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }
}
