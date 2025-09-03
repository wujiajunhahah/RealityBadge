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
    private var brightnessEMA: Double = 0.0

    override init() {
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

    // 用平均亮度做演示进度（占位：后续换 VLM/分割信号）
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixel, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixel, .readOnly) }
        let w = CVPixelBufferGetWidthOfPlane(pixel, 0)
        let h = CVPixelBufferGetHeightOfPlane(pixel, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixel, 0)
        guard let baseAddr = CVPixelBufferGetBaseAddressOfPlane(pixel, 0) else { return }
        let ptr = baseAddr.assumingMemoryBound(to: UInt8.self)

        var sum: Double = 0
        var count = 0
        let strideY = max(1, h / 120)
        let strideX = max(1, w * h / 8000)
        for y in stride(from: 0, to: h, by: strideY) {
            let row = ptr + y * bytesPerRow
            for x in stride(from: 0, to: w, by: strideX) {
                sum += Double(row[x])
                count += 1
            }
        }
        guard count > 0 else { return }
        let mean = sum / Double(count)
        let alpha = 0.06
        brightnessEMA = alpha * mean + (1 - alpha) * brightnessEMA
        var newProgress = CGFloat(min(1.0, max(0.0, brightnessEMA / 255.0)))
        newProgress = max(progress + 0.01, newProgress)

        DispatchQueue.main.async { self.progress = newProgress }
    }
}

struct CaptureView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @State private var isCapturing = false

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

                Text(cameraStatusText)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 12)

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

    private var cameraStatusText: String {
        #if targetEnvironment(simulator)
        return "模拟器不支持相机"
        #else
        return camera.isAuthorized ? "语义快门已就绪" : "需要相机权限"
        #endif
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