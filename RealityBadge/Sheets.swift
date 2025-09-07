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
                Text("立即创作")
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
                    Label("保存预览", systemImage: "square.and.arrow.down")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if let url = shareURL {
                    ShareLink(item: url) {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#34C759"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                } else {
                    Button { generateShareImage() } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
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
            Picker("预览方式", selection: $mode) {
                Text("3D卡片").tag(PreviewMode.card3D)
                Text("AR").tag(PreviewMode.ar)
                Text("沉浸").tag(PreviewMode.immersive)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            
            ZStack {
                switch mode {
                case .card3D:
                    Badge3DView(badge: badge, capturedImage: capturedImage, subjectMask: subjectMask, depthMap: depthMap)
                        .frame(height: 420)
                case .ar:
                    ARBadgeView(badge: badge)
                        .frame(height: 420)
                        .background(Color.black.opacity(0.9))
                case .immersive:
                    Badge3DView(badge: badge, capturedImage: capturedImage, subjectMask: subjectMask, depthMap: depthMap)
                        .frame(height: 560)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 12)
            
            HStack(spacing: 10) {
                Button {
                    if !saved {
                        state.recentBadges.insert(badge, at: 0)
                        saved = true
                        RBHaptics.success()
                    }
                } label: {
                    Label(saved ? "已保存" : "保存到库", systemImage: saved ? "checkmark.circle" : "square.and.arrow.down")
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
                    Label("继续拍摄", systemImage: "camera")
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
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        view.session.run(config)
        // 简易放置一个半透明的卡片
        let anchor = AnchorEntity(plane: .horizontal)
        let mesh = MeshResource.generateBox(size: 0.12, cornerRadius: 0.01)
        var mat = SimpleMaterial()
        mat.color = .init(tint: .white.withAlphaComponent(0.8), texture: nil)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.position = [0, 0, 0]
        anchor.addChild(entity)
        view.scene.addAnchor(anchor)
        return view
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
#else
struct ARBadgeView: View {
    let badge: Badge
    var body: some View { Text("AR 不可用").frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black) }
}
#endif
