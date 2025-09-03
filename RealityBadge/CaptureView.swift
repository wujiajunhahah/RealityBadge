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

final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var isAuthorized = false
    @Published var isRunning = false
    @Published var progress: CGFloat = 0.0
    @Published var error: String?

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "rb.camera.queue")

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
}

struct CaptureView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera: CameraController
    @State private var isCapturing = false

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
                VStack(spacing: 6) {
                    Text(camera.isAuthorized ? "语义快门已就绪" : "需要相机权限")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("模式：\(RBSettings().validationMode.rawValue)  ·  进度：\(Int(camera.progress * 100))%")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 8)

                // 进度环
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 6)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: camera.progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                }
                .padding(.bottom, 30)
            }
        }
        .onChange(of: camera.progress) { _, v in if v >= 1.0 { triggerCapture() } }
        .onDisappear { camera.stop() }
    }



    private func triggerCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        RBHaptics.success()
        let new = Badge(title: "摸一棵大树", date: .now, style: state.settings.style, done: true, symbol: "tree")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            state.sheet = .badgePreview(new)
        }
    }
}