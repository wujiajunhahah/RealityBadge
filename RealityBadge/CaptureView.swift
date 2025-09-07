import SwiftUI
import AVFoundation

// 用专用 UIView 承载 AVPreviewLayer，更稳
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
        uiView.previewLayer.videoGravity = .resizeAspectFill
    }
}

final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    @Published var isAuthorized = false
    @Published var isRunning = false
    @Published var progress: CGFloat = 0.0
    @Published var error: String?
    @Published var currentScores: SemanticScores?
    @Published var capturedFrame: UIImage?

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "rb.camera.queue")
    private let photoOutput = AVCapturePhotoOutput()

    // 新增：语义引擎与设置
    private let engine: SemanticEngine
    private let settings: RBSettings

    init(engine: SemanticEngine, settings: RBSettings) {
        self.engine = engine
        self.settings = settings
        super.init()
        requestPermission()
    }

    private func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    if granted { self.startSession() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func startSession() {
        queue.async {
            self.configureSession()
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            DispatchQueue.main.async { self.error = "未找到后置相机" }
            session.commitConfiguration()
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            DispatchQueue.main.async { self.error = "相机输入创建失败" }
            session.commitConfiguration()
            return
        }
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }

        if let conn = output.connection(with: .video), conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        
        // 添加照片输出
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    // 将帧送入语义引擎，根据验证模式融合进度
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let scores = engine.process(sampleBuffer: sampleBuffer)
        
        // 保存当前分数
        DispatchQueue.main.async {
            self.currentScores = scores
        }

        let fused: CGFloat
        switch settings.validationMode {
        case .strict:
            // 必须手-物互动 + 有物体 + 有语义：用几何平均，显得更"苛刻"
            fused = pow(max(0.0001, scores.objectConfidence), 0.34)
                  * pow(max(0.0001, scores.handObjectIoU), 0.33)
                  * pow(max(0.0001, scores.textImageSimilarity), 0.33)
        case .standard:
            // 物体识别为主，语义辅助：重物体、轻语义
            fused = min(1.0, (scores.objectConfidence * 0.7 + scores.textImageSimilarity * 0.3))
        case .lenient:
            // 仅语义匹配：更宽松
            fused = scores.textImageSimilarity
        }

        // 持续前进（避免来回抖动），同时限制到 0-1
        let newProgress = max(self.progress, min(1.0, fused * 1.05))
        DispatchQueue.main.async { self.progress = newProgress }
    }
    
    // 捕获照片
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        
        DispatchQueue.main.async {
            self.capturedFrame = image
        }
    }
}

struct CaptureView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera: CameraController
    @State private var isCapturing = false
    @State private var capturedImage: UIImage?
    @State private var subjectMask: UIImage?
    @State private var depthMap: UIImage?
    @State private var semanticLabel: String = ""

    init() {
        // 默认关键词占位：后续与你的挑战词/用户自创词对接
        let engine = SemanticEngine(targetKeywords: ["tree", "手", "大树"])
        // 注意：这里无法直接访问 EnvironmentObject 的 settings，所以先创建一个临时 settings。
        // 真正项目里建议把 settings 从上级注入或改为单例。
        let tmpSettings = RBSettings()
        _camera = StateObject(wrappedValue: CameraController(engine: engine, settings: tmpSettings))
    }

    var body: some View {
        ZStack {
            #if targetEnvironment(simulator)
            // 模拟器没有相机
            LinearGradient(colors: [.black, .gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .overlay(
                    Text("相机在模拟器不可用，请用真机运行")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding()
                )
                .ignoresSafeArea()
            #else
            if camera.isAuthorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            } else {
                LinearGradient(colors: [.black, .gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            #endif

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                // 状态 + 调试信息（可关）
                VStack(spacing: 8) {
                    if !semanticLabel.isEmpty {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .medium))
                            Text("识别到：\(semanticLabel)")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Text(camera.isAuthorized ? "对准物体，等待识别" : "需要相机权限")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    
                    HStack(spacing: 16) {
                        // 物体检测指示器
                        VStack(spacing: 4) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 20))
                            Text("\(Int(camera.progress * 100))%")
                                .font(.system(.caption2, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(camera.progress > 0.3 ? 1 : 0.5))
                        
                        // 手势交互指示器
                        VStack(spacing: 4) {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 20))
                            Text(camera.progress > 0.5 ? "检测到" : "未检测")
                                .font(.system(.caption2, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(camera.progress > 0.5 ? 1 : 0.5))
                        
                        // 语义匹配指示器
                        VStack(spacing: 4) {
                            Image(systemName: "text.magnifyingglass")
                                .font(.system(size: 20))
                            Text(camera.progress > 0.7 ? "匹配" : "识别中")
                                .font(.system(.caption2, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(camera.progress > 0.7 ? 1 : 0.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.bottom, 8)

                // 进度环
                ZStack {
                    // 背景环
                    Circle()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 8)
                        .frame(width: 120, height: 120)
                        .blur(radius: 1)
                    
                    // 进度环
                    Circle()
                        .trim(from: 0, to: camera.progress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                        .shadow(color: .white.opacity(0.5), radius: 10)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: camera.progress)
                    
                    // 中心按钮
                    if camera.progress >= 1.0 {
                        Circle()
                            .fill(.white)
                            .frame(width: 80, height: 80)
                            .transition(.scale.combined(with: .opacity))
                            .onAppear {
                                HapticEngine.shared.badgeUnlocked()
                            }
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text("\(Int(camera.progress * 100))%")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                }
                .padding(.bottom, 30)
                .onChange(of: camera.progress) { oldValue, newValue in
                    // 渐进式触觉反馈
                    if newValue - oldValue > 0.1 {
                        HapticEngine.shared.objectDetected(confidence: Float(newValue))
                    }
                }
            }
        }
        .onChange(of: camera.progress) { _, v in if v >= 1.0 { triggerCapture() } }
        .onChange(of: camera.currentScores?.semanticLabel) { _, newLabel in
            if let label = newLabel {
                withAnimation(.easeInOut(duration: 0.3)) {
                    semanticLabel = label
                }
            }
        }
        .onChange(of: camera.currentScores) { _, scores in
            if let scores = scores {
                subjectMask = scores.subjectMask
                depthMap = scores.depthMap
            }
        }
        .onDisappear { camera.stop() }
    }



    private func triggerCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        RBHaptics.success()
        
        // 捕获当前帧
        camera.capturePhoto()
        
        // 使用识别到的标签或默认标签
        let title = semanticLabel.isEmpty ? "未知物体" : semanticLabel
        let symbol = getSymbolForObject(title)
        
        let new = Badge(
            title: title,
            date: .now,
            style: state.settings.style,
            done: true,
            symbol: symbol
        )
        
        // 等待照片捕获完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 保存捕获的数据到state中
            if let capturedImage = self.camera.capturedFrame {
                self.state.lastCapturedImage = capturedImage
                self.state.lastSubjectMask = self.subjectMask
                self.state.lastDepthMap = self.depthMap
            }
            
            self.state.sheet = .badge3DPreview(new)
            
            // 重置状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isCapturing = false
                self.camera.progress = 0
            }
        }
    }
    
    private func getSymbolForObject(_ object: String) -> String {
        let symbolMap: [String: String] = [
            "树木": "tree",
            "咖啡杯": "cup.and.saucer",
            "雨伞": "umbrella",
            "手机": "iphone",
            "书本": "book",
            "花朵": "leaf",
            "钥匙": "key",
            "眼镜": "eyeglasses"
        ]
        return symbolMap[object] ?? "questionmark.circle"
    }
}