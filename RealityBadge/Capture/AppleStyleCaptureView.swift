import SwiftUI

// MARK: - 苹果风格拍摄界面
// 基于 Capwords 设计原则：极简、内容优先、直观

struct AppleStyleCaptureView: View {
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
            // 背景层
            backgroundLayer

            // 相机预览
            if camera.isAuthorized {
                cameraPreview
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
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                state.lastCapturedImage = image
                showPreview = true
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            AppleStylePreviewView(image: capturedImage) {
                dismiss()
            }
        }
    }

    // MARK: - 背景层
    private var backgroundLayer: some View {
        Color.black.ignoresSafeArea()
    }

    // MARK: - 相机预览
    private var cameraPreview: some View {
        CameraPreview(session: camera.session)
            .ignoresSafeArea()
            .overlay {
                // 取景框辅助线
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        recognitionStatus
                        Spacer()
                    }
                    .padding(.bottom, 120)
                }
            }
    }

    // MARK: - 权限视图
    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiaryLabel)

            Text("需要相机权限")
                .font(.system(.title3, weight: .semibold))

            Text("请在设置中允许访问相机")
                .font(.system(.subheadline))
                .foregroundStyle(.secondaryLabel)
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
            .background(.systemBlue)
            .clipShape(Capsule())
        }
        .padding(32)
    }

    // MARK: - UI 层
    private var uiLayer: some View {
        VStack {
            // 顶部工具栏（极简）
            topBar

            Spacer()

            // 底部控制区
            bottomControls
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 34) // 适配底部安全区域
    }

    // MARK: - 顶部栏
    private var topBar: some View {
        HStack {
            // 关闭按钮
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

            // 闪光灯按钮
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
    }

    // MARK: - 识别状态
    private var recognitionStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(camera.progress >= 1 ? .systemGreen : .systemBlue)
                .frame(width: 8, height: 8)

            if let label = camera.currentScores?.semanticLabel {
                Text(label)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.white)
            } else {
                Text("识别中...")
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondaryLabel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - 底部控制区
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // 模式选择器（简化版）
            modeSelector

            // 快门按钮
            shutterButton
        }
    }

    // MARK: - 模式选择器
    @State private var selectedMode: CaptureMode = .auto

    enum CaptureMode: String, CaseIterable {
        case auto = "自动"
        case photo = "照片"
        case square = "方形"

        var icon: String {
            switch self {
            case .auto: return "camera.aperture"
            case .photo: return "photo"
            case .square: return "square"
            }
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 20) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    withAnimation {
                        selectedMode = mode
                    }
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 20, weight: selectedMode == mode ? .semibold : .regular))
                        .foregroundStyle(selectedMode == mode ? .systemBlue : .white)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - 快门按钮
    private var shutterButton: some View {
        ZStack {
            // 外圈 - 进度指示
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                .frame(width: 72, height: 72)

            // 进度弧
            Circle()
                .trim(from: 0, to: camera.progress)
                .stroke(
                    LinearGradient(
                        colors: [.systemGreen, .systemBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 72, height: 72)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.3), value: camera.progress)

            // 快门按钮
            Button {
                capturePhoto()
            } label: {
                Circle()
                    .fill(camera.progress >= 1 ? .systemGreen : .white)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: camera.progress >= 1 ? "checkmark" : "camera.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(camera.progress >= 1 ? .white : .black)
                    }
            }
            .buttonStyle(.plain)
            .scaleEffect(camera.progress >= 1 ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: camera.progress)
        }
    }

    // MARK: - 拍照
    private func capturePhoto() {
        // 触觉反馈
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // 捕获照片
        camera.capturePhoto()

        // 延迟显示预览（等待照片处理完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let image = camera.capturedFrame {
                self.capturedImage = image
            }
        }
    }
}

// MARK: - 苹果风格预览界面
struct AppleStylePreviewView: View {
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
                                .foregroundStyle(.systemGreen)
                            Text("已保存")
                                .font(.system(.body, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    Button("完成") {
                        saveImage()
                    }
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.systemBlue)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                // 底部操作栏
                bottomActions
            }
        }
        .navigationBarHidden(true)
    }

    private var bottomActions: some View {
        HStack(spacing: 16) {
            ActionButton(
                icon: "arrow.uturn.backward",
                title: "重拍",
                action: onDismiss
            )

            Spacer()

            ActionButton(
                icon: "square.and.arrow.down",
                title: "保存",
                isPrimary: true,
                action: saveImage
            )

            Spacer()

            ActionButton(
                icon: "square.and.arrow.up",
                title: "分享",
                action: shareImage
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }

    private func saveImage() {
        // TODO: 实现保存逻辑
        withAnimation(.spring()) {
            showSuccess = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            onDismiss()
        }
    }

    private func shareImage() {
        // TODO: 实现分享逻辑
    }
}

// MARK: - 操作按钮
struct ActionButton: View {
    let icon: String
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    init(
        icon: String,
        title: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) {
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
                    .foregroundStyle(isPrimary ? .white : .white)

                Text(title)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 预览
#Preview {
    AppleStyleCaptureView()
        .environmentObject(AppState())
}
