import SwiftUI
import UIKit
 

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

extension UIApplication {
    func topMostController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController { return topMostController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController { return topMostController(base: tab.selectedViewController) }
        if let presented = base?.presentedViewController { return topMostController(base: presented) }
        return base
    }
}

struct BadgePreviewSheet: View {
    let badge: Badge
    @EnvironmentObject var state: AppState
    @State private var shareURL: URL?
    @StateObject private var motion = RBMotion.shared
    @State private var preset: RBSharePreset = .portrait1080x1920

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
                BadgeStampView(badge: badge)
                    .offset(x: -x/2, y: -y/2)
                    .animation(.easeOut(duration: 0.15), value: y)
            }
            .frame(height: 220)
            .padding(.horizontal, 20)
            .onAppear { motion.start(); generateShareImage() }
            .onDisappear { motion.stop() }

            // 导出尺寸选择
            Picker("尺寸", selection: $preset) {
                ForEach(RBSharePreset.allCases) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

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

            // 沉浸/AR 预览（从库进入）
            if let raw = badge.capturePath, let img = UIImage(contentsOfFile: raw) {
                HStack(spacing: 12) {
                    Button {
                        let maskImg: CGImage? = {
                            if let m = badge.maskPath, let cg = UIImage(contentsOfFile: m)?.cgImage { return cg }
                            return nil
                        }()
                        let depthImg: CGImage? = {
                            if let d = badge.depthPath, let cg = UIImage(contentsOfFile: d)?.cgImage { return cg }
                            return nil
                        }()
                        state.sheet = .immersive(image: img, mask: maskImg, depth: depthImg)
                    } label: {
                        Label("沉浸预览", systemImage: "view.3d")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Button {
                        state.sheet = .arDesk(image: img)
                    } label: {
                        Label("桌面预览(AR)", systemImage: "arkit")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .padding(.bottom, 12)
        .onDisappear {
            // 徽章预览结束，允许下一次创作
            NotificationCenter.default.post(name: .rbCaptureResume, object: nil)
        }
    }

    @MainActor
    private func generateShareImage() {
        shareURL = ShareExporter.exportPNG(for: badge, preset: preset)
    }
}
