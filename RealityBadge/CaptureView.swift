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
    
    // 对外公开的启动方法（用于返回拍摄界面后重启相机）
    func start() {
        if isAuthorized {
            if !session.isRunning { startSession() }
        } else {
            requestPermission()
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

        if let conn = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if conn.isVideoRotationAngleSupported(90) {
                    conn.videoRotationAngle = 90
                }
            } else if conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
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
        // 目标关键词（含英文同义词），覆盖屏幕/iPad/耳机/水杯/雨伞/纸张等
        let targets: [String] = [
            // 屏幕/显示类
            "screen","display","monitor","tv","laptop","computer",
            // iPad/平板/手机
            "ipad","tablet","iphone","phone","mobile",
            // 耳机
            "headphones","earbuds","earphones","airpods","headset",
            // 水杯/杯子
            "cup","mug","coffee","tumbler","bottle",
            // 雨伞
            "umbrella",
            // 纸张/文件
            "paper","document","doc","sheet","page","notebook","book"
        ]
        let engine = SemanticEngine(targetKeywords: targets)
        // 注意：这里无法直接访问 EnvironmentObject 的 settings，所以先创建一个临时 settings。
        // 真正项目里建议把 settings 从上级注入或改为单例。
        let tmpSettings = RBSettings()
        _camera = StateObject(wrappedValue: CameraController(engine: engine, settings: tmpSettings))
    }

    var body: some View {
        ZStack {
            backgroundView
            mainContent
        }
        // 稳定1.5秒后再触发
        .onChange(of: camera.progress) { _, _ in handleProgressStability() }
        .onChange(of: camera.currentScores?.semanticLabel) { _, newLabel in
            if let label = newLabel {
                withAnimation(.easeInOut(duration: 0.3)) {
                    semanticLabel = label
                }
            }
        }
        .onReceive(camera.$currentScores) { scores in
            if let scores = scores {
                subjectMask = scores.subjectMask
                depthMap = scores.depthMap
            }
        }
        // 预览弹出时停止相机，关闭后再由视图生命周期决定是否重启
        .onReceive(state.$sheet) { route in
            if route != nil { camera.stop() }
        }
        .onAppear {
            if camera.isAuthorized { camera.start() }
        }
        .onDisappear { camera.stop() }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
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
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack {
            topBar
            Spacer()
            statusSection
            progressRing
        }
    }
    
    @ViewBuilder
    private var topBar: some View {
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
    }
    
    @ViewBuilder
    private var statusSection: some View {
        VStack(spacing: 8) {
            if !semanticLabel.isEmpty {
                semanticLabelView
            }
            
            Text(camera.isAuthorized ? "对准物体，等待识别" : "需要相机权限")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            
            indicatorsView
        }
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var semanticLabelView: some View {
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
    
    @ViewBuilder
    private var indicatorsView: some View {
        HStack(spacing: 16) {
            indicatorView(
                icon: "viewfinder",
                text: "\(Int(camera.progress * 100))%",
                isActive: camera.progress > 0.3
            )
            
            indicatorView(
                icon: "hand.raised",
                text: camera.progress > 0.5 ? "检测到" : "未检测",
                isActive: camera.progress > 0.5
            )
            
            indicatorView(
                icon: "text.magnifyingglass",
                text: camera.progress > 0.7 ? "匹配" : "识别中",
                isActive: camera.progress > 0.7
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .advancedMaterial(.glass)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func indicatorView(icon: String, text: String, isActive: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
            Text(text)
                .font(.system(.caption2, design: .rounded))
        }
        .foregroundStyle(.white.opacity(isActive ? 1 : 0.5))
    }
    
    @ViewBuilder
    private var progressRing: some View {
        ZStack {
            backgroundRing
            progressCircle
            centerButton
        }
        .padding(.bottom, 30)
        .onChange(of: camera.progress) { oldValue, newValue in
            if newValue - oldValue > 0.1 {
                HapticEngine.shared.objectDetected(confidence: Float(newValue))
            }
        }
    }
    
    @ViewBuilder
    private var backgroundRing: some View {
        Circle()
            .strokeBorder(Color.white.opacity(0.15), lineWidth: 8)
            .frame(width: 120, height: 120)
            .blur(radius: 1)
    }
    
    @ViewBuilder
    private var progressCircle: some View {
        Circle()
            .trim(from: 0, to: camera.progress)
            .stroke(
                LinearGradient(
                    colors: [Color.white, Color.white.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 120, height: 120)
            .shadow(color: .white.opacity(0.5), radius: 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: camera.progress)
    }
    
    @ViewBuilder
    private var centerButton: some View {
        if camera.progress >= 1.0 {
            Circle()
                .fill(.white)
                .frame(width: 80, height: 80)
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    HapticEngine.shared.badgeUnlocked()
                }
        } else if camera.progress >= 0.9 {
            Button(action: { triggerCapture() }) {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text("生成")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
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
            // 停止相机，避免后台继续采集
            self.camera.stop()
            
            self.state.sheet = .badge3DPreview(new)
            
            // 重置状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isCapturing = false
                self.camera.progress = 0
            }
        }
    }
    
    // MARK: - 稳定触发逻辑（满1.5秒）
    @State private var stableStart: Date? = nil
    private func handleProgressStability() {
        let p = camera.progress
        if p >= 1.0 {
            if stableStart == nil { stableStart = .now }
            if let s = stableStart, Date().timeIntervalSince(s) >= 1.5 {
                stableStart = nil
                triggerCapture()
            }
        } else if p < 0.95 {
            stableStart = nil
        }
    }
    
    private func getSymbolForObject(_ object: String) -> String {
        let s = object.lowercased()
        // 设备类
        if s.contains("ipad") || s.contains("tablet") { return "ipad" }
        if s.contains("iphone") || s.contains("phone") || s.contains("mobile") { return "iphone" }
        if s.contains("screen") || s.contains("display") || s.contains("monitor") || s.contains("tv") { return "display" }
        
        // 音频类
        if s.contains("headphone") || s.contains("headset") || s.contains("earbud") || s.contains("earphone") || s.contains("airpods") { return "headphones" }
        
        // 杯子/水杯
        if s.contains("cup") || s.contains("mug") || s.contains("tumbler") || s.contains("bottle") || s.contains("coffee") { return "cup.and.saucer" }
        
        // 雨伞
        if s.contains("umbrella") { return "umbrella" }
        
        // 纸张/文件/书本
        if s.contains("paper") || s.contains("document") || s.contains("doc") || s.contains("sheet") || s.contains("page") { return "doc.text" }
        if s.contains("book") || s.contains("notebook") { return "book" }
        
        // 常见中文映射（兼容之前）
        let cnMap: [String: String] = [
            "树木": "tree",
            "咖啡杯": "cup.and.saucer",
            "雨伞": "umbrella",
            "手机": "iphone",
            "书本": "book",
            "花朵": "leaf",
            "钥匙": "key",
            "眼镜": "eyeglasses"
        ]
        if let m = cnMap[object] { return m }
        return "questionmark.circle"
    }
}
