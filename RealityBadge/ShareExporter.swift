import Foundation
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

enum RBSharePreset: String, CaseIterable, Identifiable {
    case portrait1080x1920
    case portrait1080x1350
    case landscape1280x720
    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .portrait1080x1920: return CGSize(width: 1080, height: 1920)
        case .portrait1080x1350: return CGSize(width: 1080, height: 1350)
        case .landscape1280x720: return CGSize(width: 1280, height: 720)
        }
    }
    var label: String {
        switch self {
        case .portrait1080x1920: return "1080×1920"
        case .portrait1080x1350: return "1080×1350"
        case .landscape1280x720: return "1280×720"
        }
    }
}

enum ShareExporter {
    @MainActor
    static func exportPNG(for badge: Badge, preset: RBSharePreset) -> URL? {
        // 1) 渲染卡片视图到指定尺寸
        let card = cardView(badge: badge, size: preset.size, stampScale: 1.0)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
        guard let ui = renderer.uiImage else { return nil }

        // 2) 轻微锐化 + 边缘描线，提升社媒压缩后的清晰度
        let sharpened = sharpen(image: ui)
        guard let data = sharpened.pngData() else { return nil }

        // 3) 写入临时目录
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rb_share_\(UUID().uuidString).png")
        do { try data.write(to: tmp) } catch { return nil }
        return tmp
    }

    static func cardView(badge: Badge, size: CGSize, stampScale: CGFloat) -> some View {
        ZStack {
            // 背景（不黑化，柔和浅色）
            LinearGradient(colors: [Color(hex: "#F6F8FF"), Color.white], startPoint: .top, endPoint: .bottom)
            // 内容卡片
            VStack(spacing: 20) {
                Spacer(minLength: 24)
                // 贴纸主体（更大、更醒目、可自适应填满）
                StickerView(badge: badge)
                    .frame(width: size.width * 0.86, height: size.height * 0.66)
                // 文案
                Text(badge.title)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)
                Text(dateString(badge.date))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                HStack {
                    Text("RealityBadge").font(.system(.footnote, design: .rounded).weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(presetLabel(size: size)).font(.system(.footnote, design: .rounded)).foregroundStyle(.white.opacity(0.35))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // 贴纸风主体：大幅填充，带白边 + 阴影 + 轻转角
    private struct StickerView: View {
        let badge: Badge
        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let r: CGFloat = min(w, h) * 0.08
                ZStack {
                    // 阴影层
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white.opacity(0.001))
                        .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 18)
                    // 背板（白色贴纸）
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: r)
                                .stroke(Color.black.opacity(0.08), lineWidth: 2)
                        )
                    // 内容图填充（自适应裁剪）
                    Group {
                        if let p = badge.imagePath, let ui = UIImage(contentsOfFile: p) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: w*0.94, height: h*0.86)
                                .clipShape(RoundedRectangle(cornerRadius: r * 0.6))
                        } else {
                            BadgeStampView(badge: badge)
                                .frame(width: w*0.9, height: h*0.8)
                        }
                    }
                    .padding(.top, 10)
                }
                .rotationEffect(.degrees(-2.0))
            }
        }
    }

    private static func presetLabel(size: CGSize) -> String {
        "\(Int(size.width))×\(Int(size.height))"
    }

    private static func sharpen(image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let context = CIContext()

        // 轻锐化 + 轻边缘
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = ciImage
        sharpen.sharpness = 0.35
        sharpen.radius = 0.8

        let edges = CIFilter.edges()
        edges.inputImage = sharpen.outputImage
        edges.intensity = 1.0

        guard let out = edges.outputImage,
              let cg = context.createCGImage(out, from: out.extent) else { return image }
        return UIImage(cgImage: cg)
    }
}
