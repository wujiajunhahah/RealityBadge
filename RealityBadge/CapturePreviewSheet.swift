import SwiftUI

struct CapturePreviewSheet: View {
    let image: UIImage
    let mask: CGImage?
    let depth: CGImage?
    var suggestedTitle: String?
    var onMakeBadge: (Badge) -> Void

    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 44, height: 5).padding(.top, 6)
            Text(suggestedTitle ?? "动态预览 · 语义快门")
                .font(.system(.headline, design: .rounded).weight(.semibold))

            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground))
                ParallaxPreviewView(image: image, mask: mask, interactive: true)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .frame(height: 280)
            .padding(.horizontal, 20)
            .overlay(alignment: .topTrailing) {
                Text("空间")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)
            }

            HStack(spacing: 12) {
                Button {
                    // 合成真实徽章图并持久化
                    let style = state.settings.style
                    if let composed = BadgeComposer.compose(from: image, mask: mask, style: style) {
                        var badge = Badge(title: suggestedTitle ?? "语义快门", date: .now, style: style, done: true, symbol: "seal")
                        if let saved = BadgeComposer.saveBadgeImages(image: composed, id: badge.id) {
                            badge.imagePath = saved.imagePath
                            badge.thumbPath = saved.thumbPath
                        }
                        if let raw = BadgeComposer.saveRaw(image: image, mask: mask, depth: nil, id: badge.id) {
                            badge.capturePath = raw.capturePath
                            badge.maskPath = raw.maskPath
                            badge.depthPath = raw.depthPath
                        }
                        onMakeBadge(badge)
                    } else {
                        let badge = Badge(title: suggestedTitle ?? "语义快门", date: .now, style: style, done: true, symbol: "seal")
                        onMakeBadge(badge)
                    }
                } label: {
                    Label("生成徽章", systemImage: "seal")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RBColors.green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Button {
                    // 直接保存静态图
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                } label: {
                    Label("保存图片", systemImage: "square.and.arrow.down")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // 沉浸/AR 预览
            HStack(spacing: 12) {
                Button { state.sheet = .immersive(image: image, mask: mask, depth: depth) } label: {
                    Label("沉浸预览", systemImage: "view.3d")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Button { state.sheet = .arDesk(image: image) } label: {
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
        .padding(.bottom, 12)
        .onDisappear {
            // 预览结束，允许下一次创作
            NotificationCenter.default.post(name: .rbCaptureResume, object: nil)
        }
    }
}
