import SwiftUI
import UIKit
import AVKit
#if canImport(ARKit)
import ARKit
#endif
#if canImport(RealityKit)
import RealityKit
#endif

struct ChallengeSheet: View {
    let title: String
    let hint: String
    var onAccept: () -> Void
    
    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 44, height: 5).padding(.top, 6)
            Text(title).font(.system(.title3, design: .rounded).weight(.semibold))
            Text(hint).font(.system(.footnote, design: .rounded)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Image(systemName: "seal")
                .font(.system(size: 40, weight: .semibold))
                .padding(8)
            Button(action: onAccept) {
                Text(RBStrings.t(.createNow))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#34C759"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .padding(.bottom, 12)
    }
}

struct BadgePreviewSheet: View {
    let badge: Badge
    @State private var shareURL: URL?
    @StateObject private var motion = RBMotion.shared

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 44, height: 5).padding(.top, 6)
            Text(badge.title).font(.system(.title3, design: .rounded).weight(.semibold))
            ZStack {
                let x = motion.roll * 10
                let y = motion.pitch * 10
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .offset(x: x, y: y)
                    .animation(.easeOut(duration: 0.15), value: x)
                VStack(spacing: 10) {
                    Image(systemName: badge.symbol).font(.system(size: 46, weight: .semibold))
                    Text(dateString(badge.date)).font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
                }
                .offset(x: -x/2, y: -y/2)
                .animation(.easeOut(duration: 0.15), value: y)
            }
            .frame(height: 220)
            .padding(.horizontal, 20)
            .onAppear { motion.start(); generateShareImage() }
            .onDisappear { motion.stop() }

            HStack(spacing: 12) {
                Button { generateShareImage() } label: {
                    Label("Save Preview", systemImage: "square.and.arrow.down")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if let url = shareURL {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#34C759"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                } else {
                    Button { generateShareImage() } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#34C759"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .padding(.bottom, 12)
    }

    @MainActor
    private func generateShareImage() {
        // 将预览渲染为图片写入临时目录
        let card = ZStack {
            RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground))
            VStack(spacing: 12) {
                Image(systemName: badge.symbol).font(.system(size: 80, weight: .semibold))
                Text(badge.title).font(.system(.title3, design: .rounded).weight(.semibold))
                Text(dateString(badge.date)).font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
            }.padding(24)
        }.frame(width: 600, height: 600)

        let renderer = ImageRenderer(content: card)
        if let ui = renderer.uiImage, let data = ui.pngData() {
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rb_share_\(UUID().uuidString).png")
            try? data.write(to: tmp)
            shareURL = tmp
        }
    }
}

// MARK: - Capture Result with Modes
enum PreviewMode: String, CaseIterable, Identifiable { case card3D, ar, immersive; var id: String { rawValue } }

struct BadgeResultSheet: View {
    @EnvironmentObject var state: AppState
    let badge: Badge
    let capturedImage: UIImage?
    let subjectMask: UIImage?
    let depthMap: UIImage?
    @State private var mode: PreviewMode = .card3D
    @State private var saved = false
    
    var body: some View {
        VStack(spacing: 12) {
            Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 44, height: 5).padding(.top, 6)
            // Segmented control
            Picker(RBStrings.t(.previewMode), selection: $mode) {
                Text(RBStrings.t(.card3D)).tag(PreviewMode.card3D)
                Text(RBStrings.t(.ar)).tag(PreviewMode.ar)
                Text(RBStrings.t(.immersive)).tag(PreviewMode.immersive)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            
            ZStack {
                switch mode {
                case .card3D:
                    Badge3DView(badge: badge, capturedImage: capturedImage, subjectMask: subjectMask, depthMap: depthMap)
                        .frame(height: 420)
                case .ar:
                    ARBadgeView(badge: badge, image: capturedImage)
                        .frame(height: 420)
                        .background(Color.black.opacity(0.9))
                case .immersive:
                    ImmersivePhotoView(image: capturedImage)
                        .frame(height: 560)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 12)
            
            HStack(spacing: 10) {
                Button {
                    guard !saved else { return }
                    // 将资源落盘，并构造带路径的Badge
                    let paths = saveCurrentAssets(badge: badge, image: capturedImage, mask: subjectMask, depth: depthMap)
                    let savedBadge = Badge(
                        title: badge.title,
                        date: badge.date,
                        style: badge.style,
                        done: true,
                        symbol: badge.symbol,
                        imagePath: paths.image,
                        maskPath: paths.mask,
                        depthPath: paths.depth
                    )
                    state.recentBadges.insert(savedBadge, at: 0)
                    RBRepository.badges.save(savedBadge)
                    saved = true
                    RBHaptics.success()
                } label: {
                    Label(saved ? "Saved" : RBStrings.t(.saveToLibrary), systemImage: saved ? "checkmark.circle" : "square.and.arrow.down")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(saved ? Color.green.opacity(0.6) : Color.white.opacity(0.15), lineWidth: saved ? 2 : 1)
                        )
                }
                Button {
                    // 继续下一次拍摄
                    state.sheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        state.showCapture = true
                    }
                } label: {
                    Label(RBStrings.t(.continue), systemImage: "camera")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#34C759"), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .padding(.bottom, 10)
    }
}

#if canImport(RealityKit) && canImport(ARKit)
struct ARBadgeView: UIViewRepresentable {
    let badge: Badge
    var image: UIImage?
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        view.session.run(config)
        // Coaching overlay for better plane detection
        let coaching = ARCoachingOverlayView()
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.goal = .horizontalPlane
        coaching.session = view.session
        view.addSubview(coaching)

        // Tap to place a card entity (with photo texture)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        context.coordinator.image = image
        
        return view
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject {
        weak var view: ARView?
        var image: UIImage?
        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard let view = view else { return }
            let loc = gr.location(in: view)
            if let result = view.raycast(from: loc, allowing: .estimatedPlane, alignment: .horizontal).first {
                let anchor = AnchorEntity(world: result.worldTransform)
                // Use a thin box for better visual presence (not just flat)
                let w: Float = 0.18
                let h: Float = 0.11
                let t: Float = 0.003
                let mesh = MeshResource.generateBox(size: [w, t, h], cornerRadius: 0.01)
                var mat: RealityKit.Material
                if let img = image, let cg = img.cgImage, let tex = try? TextureResource.generate(from: cg, options: .init(semantic: .color)) {
                    var pbr = PhysicallyBasedMaterial()
                    pbr.baseColor = .init(texture: .init(tex))
                    pbr.roughness = 0.4
                    pbr.metallic = 0.0
                    mat = pbr
                } else {
                    var pbr = PhysicallyBasedMaterial()
                    pbr.baseColor = .init(tint: .white.withAlphaComponent(0.95))
                    pbr.roughness = 0.4
                    mat = pbr
                }
                let card = ModelEntity(mesh: mesh, materials: [mat])
                // Soft bounce-in animation
                card.transform.translation = [0, 0.02, 0]
                anchor.addChild(card)
                view.scene.addAnchor(anchor)
                card.move(to: Transform(), relativeTo: anchor, duration: 0.5, timingFunction: RealityKit.AnimationTimingFunction.easeOut)
                // Enable translation / rotation / scale gestures for interaction
                view.installGestures([.translation, .rotation, .scale], for: card)
            }
        }
    }
}
#else
struct ARBadgeView: View {
    let badge: Badge
    var body: some View { Text("AR not available").frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black.opacity(0.05)) }
}
#endif

// MARK: - 沉浸式照片（全屏 + 陀螺仪视差）
struct ImmersivePhotoView: View {
    let image: UIImage?
    @StateObject private var motion = RBMotion.shared
    
    private func offset(for size: CGSize) -> CGSize {
        // 将 roll/pitch（-pi..pi）映射为最多 6% 视差位移
        let maxX = size.width * 0.06
        let maxY = size.height * 0.06
        let ox = CGFloat(max(-1, min(1, motion.roll))) * maxX
        let oy = CGFloat(max(-1, min(1, motion.pitch))) * maxY
        return CGSize(width: -ox, height: -oy) // 反向位移制造景深感
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.ignoresSafeArea()
                if let ui = image {
                    // 轻微放大避免视差暴露边缘
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(1.12)
                        .offset(offset(for: geo.size))
                        .clipped()
                        .ignoresSafeArea()
                } else {
                    LinearGradient(colors: [Color(hex: "#F7FBFF"), Color(hex: "#F3F8FF")], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                }
                
                // 轻微的前景高光，模拟“液态玻璃”质感
                if #available(iOS 16.0, *) {
                    LiquidGlassView(opacity: 0.12, blur: 8)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }
            }
            .onAppear {
                motion.start()
                HapticEngine.shared.liquidTransition()
            }
            .onDisappear { motion.stop() }
        }
    }
}

// 保存图片到文档目录
private func saveCurrentAssets(badge: Badge, image: UIImage?, mask: UIImage?, depth: UIImage?) -> (image: String?, mask: String?, depth: String?) {
    func save(_ img: UIImage?, name: String) -> String? {
        guard let data = img?.pngData() else { return nil }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        do { try data.write(to: url); return url.path } catch { return nil }
    }
    let base = badge.id.uuidString
    return (
        save(image, name: "\(base)_img.png"),
        save(mask, name: "\(base)_mask.png"),
        save(depth, name: "\(base)_depth.png")
    )
}
