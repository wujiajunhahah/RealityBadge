import SwiftUI
import AVFoundation
import CoreVideo
import UIKit

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

final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, AVCaptureDepthDataOutputDelegate {
    @Published var isAuthorized = false
    @Published var isRunning = false
    @Published var progress: CGFloat = 0.0
    @Published var error: String?
    @Published var scores: SemanticScores = .init(objectConfidence: 0, handObjectIoU: 0, textImageSimilarity: 0)
    @Published var isVerified: Bool = false
    @Published var hint: String = "保持稳定，准备自动抓拍"
    @Published var bestLabel: String? = nil

    // 新增：流水杯识别计时器
    @Published var cupDetectionTime: TimeInterval = 0
    @Published var isCupDetected: Bool = false
    @Published var autoCaptureEnabled: Bool = true

    private var cupDetectionStartTime: Date?
    private var autoCaptureTimer: Timer?

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "rb.camera.queue")
    private let syncQueue = DispatchQueue(label: "rb.depth.queue")

    // 新增：语义引擎与设置
    private let engine: SemanticEngine
    private let settings: RBSettings
    private let gate = StabilityGate(requiredFrames: 12, maxWindow: 18, driftTolerance: 0.12)
    private var lastPixelBuffer: CVPixelBuffer?
    private var lastDepthBuffer: CVPixelBuffer?

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

        // 深度数据（如支持）
        let depthOutput = AVCaptureDepthDataOutput()
        depthOutput.isFilteringEnabled = true
        if session.canAddOutput(depthOutput) {
            session.addOutput(depthOutput)
            depthOutput.setDelegate(self, callbackQueue: syncQueue)
            if let dconn = depthOutput.connection(with: .depthData), dconn.isVideoOrientationSupported { dconn.videoOrientation = .portrait }
            // 选择支持深度的 format
            if let best = device.activeFormat.supportedDepthDataFormats.first {
                try? device.lockForConfiguration(); device.activeDepthDataFormat = best; device.unlockForConfiguration()
            }
        }
        session.commitConfiguration()
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    // 恢复下一次创作：清理状态、重置稳定门槛
    func resetCycle() {
        gate.reset()
        DispatchQueue.main.async {
            self.progress = 0
            self.isVerified = false
            self.scores = .init(objectConfidence: 0, handObjectIoU: 0, textImageSimilarity: 0)
            self.isCupDetected = false
            self.cupDetectionStartTime = nil
            self.cupDetectionTime = 0
            self.autoCaptureEnabled = true
            self.hint = "保持稳定，准备自动抓拍"
        }
    }

    // 将帧送入语义引擎，根据验证模式融合进度
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pb = CMSampleBufferGetImageBuffer(sampleBuffer) {
            self.lastPixelBuffer = pb
        }
        let scores = engine.process(sampleBuffer: sampleBuffer)

        var fused: CGFloat
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

        // 若明显命中目标但没有手部互动（适配“笑/月亮/黑衣服”等无需手部参与的类目），给予保底融合
        if scores.handObjectIoU < 0.15 && scores.objectConfidence >= 0.75 && scores.textImageSimilarity >= 0.6 {
            let fallback = min(1.0, scores.objectConfidence * 0.8 + scores.textImageSimilarity * 0.2)
            fused = max(fused, fallback)
        }

        // 持续前进（避免来回抖动），同时限制到 0-1
        let newProgress = max(self.progress, min(1.0, fused * 1.05))

        // 动态阈值（不同验证模式）
        let threshold: CGFloat = {
            switch settings.validationMode {
            case .strict:   return 0.85
            case .standard: return 0.70
            case .lenient:  return 0.55
            }
        }()
        let result = gate.push(scores: scores, fused: fused, threshold: threshold, mode: settings.validationMode)

        // 新增：流水杯识别逻辑
        let isCupDetected = self.isCupDetected(scores: scores)
        self.updateCupDetectionState(isCupDetected)

        DispatchQueue.main.async {
            self.progress = newProgress
            self.scores = scores
            self.isVerified = result.passed
            self.hint = result.hint
            self.bestLabel = self.engine.bestLabel()
        }
    }

    // 深度数据回调
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        lastDepthBuffer = depthData.depthDataMap
    }

    // 新增：检测是否识别到流水杯
    private func isCupDetected(scores: SemanticScores) -> Bool {
        // 检查是否包含流水杯相关的关键词匹配
        // 降低阈值以适应VLM模型的输出范围
        let hasSemanticMatch = scores.textImageSimilarity > 0.3  // 从0.7降低到0.3
        let hasObjectMatch = scores.objectConfidence > 0.4      // 从0.6降低到0.4

        // 只要有语义匹配或物体匹配就算检测到
        return hasSemanticMatch || hasObjectMatch
    }

    // 新增：更新流水杯检测状态
    private func updateCupDetectionState(_ detected: Bool) {
        DispatchQueue.main.async {
            if detected {
                if !self.isCupDetected {
                    // 开始检测到目标
                    self.isCupDetected = true
                    self.cupDetectionStartTime = Date()
                    self.cupDetectionTime = 0
                    self.hint = "检测到物体，正在计时..."
                } else {
                    // 继续检测，更新时间
                    if let startTime = self.cupDetectionStartTime {
                        self.cupDetectionTime = Date().timeIntervalSince(startTime)

                        // 检查是否超过2秒
                        if self.cupDetectionTime >= 2.0 && self.autoCaptureEnabled {
                            self.autoCaptureEnabled = false // 防止重复触发
                            self.performAutoCapture()
                        }
                    }
                }
            } else {
                if self.isCupDetected {
                    // 失去检测
                    self.isCupDetected = false
                    self.cupDetectionStartTime = nil
                    self.cupDetectionTime = 0
                    self.hint = "保持稳定，准备自动抓拍"
                }
            }
        }
    }

    // 新增：执行自动拍照
    private func performAutoCapture() {
        DispatchQueue.main.async {
            self.hint = "🎉 识别成功！正在拍照..."
            self.isVerified = true

            // 添加拍照逻辑
            self.capturePhotoFromStream()

            // 重置状态，准备下次检测
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.isCupDetected = false
                self.cupDetectionStartTime = nil
                self.cupDetectionTime = 0
                self.autoCaptureEnabled = true
                self.isVerified = false
                self.hint = "保持稳定，准备自动抓拍"
            }
        }
    }

    // 新增：从相机流中拍照并保存
    private func capturePhotoFromStream() {
        // 创建照片输出
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // 新增：处理拍照结果
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.hint = "拍照失败，请重试"
            }
            return
        }

        // 保存照片到相册
        savePhotoToAlbum(uiImage)

        DispatchQueue.main.async {
            self.hint = "✅ 照片已保存到相册！"
            RBHaptics.success()
        }
    }

    // 快照 + 前景掩膜（可选）+ 深度图（可选）
    func snapshotWithMask(completion: @escaping (UIImage?, CGImage?, CGImage?) -> Void) {
        guard let pb = lastPixelBuffer else { completion(nil, nil, nil); return }
        var img: UIImage? = nil
        var mask: CGImage? = nil
        var depth: CGImage? = nil
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            img = ForegroundMasker.image(from: pb)
            group.leave()
        }
        if #available(iOS 17.0, *) {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                mask = ForegroundMasker.mask(from: pb)
                group.leave()
            }
        }
        if let db = lastDepthBuffer { // 粗略转换为 CGImage
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let ci = CIImage(cvPixelBuffer: db)
                let ctx = CIContext()
                depth = ctx.createCGImage(ci, from: ci.extent)
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(img, mask, depth) }
    }

    // 新增：保存照片到相册
    private func savePhotoToAlbum(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    // 新增：照片保存回调
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            DispatchQueue.main.async {
                self.hint = "保存失败：\(error.localizedDescription)"
            }
        } else {
            DispatchQueue.main.async {
                self.hint = "📸 照片已保存到相册！"
            }
        }
    }
}

struct CaptureView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera: CameraController
    @State private var isCapturing = false
    @State private var didPreHaptic = false

    init() {
        // 目标改为：瓶子/屏幕/电脑（移除 cup，偏向 bottle）
        let engine = SemanticEngine(targetKeywords: [
            // 瓶子 / 水杯（英文优先）
            "bottle", "water bottle", "drinking bottle",
            // 屏幕
            "screen", "monitor", "display", "television", "tv",
            // 电脑
            "computer", "laptop", "desktop", "notebook", "macbook", "pc",
            // 中文关键词（供 VLM 文本相似度使用）
            "水杯", "屏幕", "电脑"
        ])
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

                    // 新增：流水杯检测状态
                    if camera.isCupDetected {
                        HStack(spacing: 8) {
                            Image(systemName: "viewfinder")
                                .foregroundColor(.green)
                            Text("目标检测中...")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(.green.opacity(0.9))
                            Text(String(format: "%.1fs", camera.cupDetectionTime))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.green.opacity(0.7))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }

                    Text("模式：\(RBSettings().validationMode.rawValue)  ·  进度：\(Int(camera.progress * 100))%")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    calibrationBars(scores: camera.scores)
                    Text(camera.hint)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
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
        .onChange(of: camera.progress) { old, v in
            if !didPreHaptic, v >= 0.92 {
                didPreHaptic = true
                RBHaptics.light()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rbCaptureResume)) { _ in
            // 预览/保存流程结束，恢复下一次创作
            didPreHaptic = false
            isCapturing = false
            camera.resetCycle()
        }
        .onChange(of: camera.isVerified) { _, ok in if ok { triggerCapture() } }
        .onDisappear { camera.stop() }
    }



    private func triggerCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        RBHaptics.success()
        camera.snapshotWithMask { img, mask, depth in
            guard let img else {
                // 回退到老的徽章预览
                let new = Badge(title: self.displayNameForLabel(camera.bestLabel), date: .now, style: state.settings.style, done: true, symbol: "seal")
                state.recentBadges.insert(new, at: 0)
                BadgeStore.save(state.recentBadges)
                state.sheet = .badgePreview(new)
                return
            }
            state.sheet = .capturePreview(image: img, mask: mask, title: self.displayNameForLabel(camera.bestLabel), depth: depth)
        }
    }

    private func displayNameForLabel(_ label: String?) -> String {
        guard let l = label?.lowercased() else { return "语义快门" }
        if ["screen","monitor","display","television","tv"].contains(where: { l.contains($0) }) { return "屏幕" }
        if ["computer","laptop","desktop","notebook","macbook","pc"].contains(where: { l.contains($0) }) { return "电脑" }
        if ["bottle","water bottle","drinking bottle"].contains(where: { l.contains($0) }) { return "水杯" }
        return l
    }

    @ViewBuilder
    private func calibrationBars(scores: SemanticScores) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                bar(title: "物体", value: scores.objectConfidence, color: .green)
                bar(title: "互动", value: scores.handObjectIoU, color: .yellow)
                bar(title: "语义", value: scores.textImageSimilarity, color: .orange)
            }
            .frame(height: 6)
            .padding(.horizontal, 24)
        }
    }

    private func bar(title: String, value: CGFloat, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule().fill(color).frame(width: max(0, min(geo.size.width, geo.size.width * value)))
            }
            .accessibilityLabel(Text("\(title) \(Int(value * 100))%"))
        }
    }

    // 不再提供取景灰框（语义快门）
}
