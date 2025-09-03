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