import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum BadgeComposer {
    static func compose(from image: UIImage, mask: CGImage?, style: String) -> UIImage? {
        let size = CGSize(width: 1024, height: 1024)
        // 1) 前景抠图（可选）
        let fg = maskedImage(image: image, mask: mask) ?? image
        // 2) 画布 + 风格
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        // 背景
        let bgTop = UIColor(white: 0.08, alpha: 1)
        let bgBot = UIColor(white: 0.12, alpha: 1)
        let colors = [bgTop.cgColor, bgBot.cgColor] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0,1])
        ctx.drawLinearGradient(grad!, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])

        // 版式
        switch style {
        case "film":
            drawFilm(on: ctx, size: size, image: fg)
        case "pixel":
            drawPixel(on: ctx, size: size, image: fg)
        default:
            drawEmbossed(on: ctx, size: size, image: fg)
        }

        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }

    private static func maskedImage(image: UIImage, mask: CGImage?) -> UIImage? {
        guard let mask else { return nil }
        guard let cg = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cg)
        let ciMask = CIImage(cgImage: mask)
        let context = CIContext()
        guard let filter = CIFilter(name: "CIBlendWithMask") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIImage(color: .clear).cropped(to: ciImage.extent), forKey: kCIInputBackgroundImageKey)
        filter.setValue(ciMask, forKey: kCIInputMaskImageKey)
        guard let out = filter.outputImage, let cgOut = context.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cgOut)
    }

    private static func drawEmbossed(on ctx: CGContext, size: CGSize, image: UIImage) {
        let rect = CGRect(x: (size.width-720)/2, y: (size.height-720)/2 - 30, width: 720, height: 720)
        // 圆章底
        let path = UIBezierPath(ovalIn: rect)
        ctx.setFillColor(UIColor.systemBackground.cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
        // 内圈
        ctx.setStrokeColor(UIColor(white: 0, alpha: 0.08).cgColor)
        ctx.setLineWidth(12)
        ctx.addPath(UIBezierPath(ovalIn: rect.insetBy(dx: 24, dy: 24)).cgPath)
        ctx.strokePath()

        // 图像置入
        let insetRect = rect.insetBy(dx: 80, dy: 80)
        image.draw(in: insetRect)
        // 标题栏（占位）
        let label = "RealityBadge"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 40, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let text = NSAttributedString(string: label, attributes: attrs)
        text.draw(at: CGPoint(x: (size.width - text.size().width)/2, y: rect.maxY + 24))
    }

    private static func drawFilm(on ctx: CGContext, size: CGSize, image: UIImage) {
        let card = CGRect(x: 112, y: 140, width: size.width-224, height: size.height-360)
        // 胶片边
        ctx.setFillColor(UIColor.black.cgColor)
        let rounded = UIBezierPath(roundedRect: card, cornerRadius: 28)
        ctx.addPath(rounded.cgPath)
        ctx.fillPath()
        // 打孔
        let hole = CGRect(x: card.minX+12, y: card.minY+12, width: card.width-24, height: 12)
        ctx.setFillColor(UIColor.systemBackground.cgColor)
        for i in 0..<10 { ctx.fill(hole.offsetBy(dx: 0, dy: CGFloat(i)*((card.height-24)/9))) }
        // 内容
        let inner = card.insetBy(dx: 36, dy: 36)
        ctx.setFillColor(UIColor.systemBackground.cgColor)
        ctx.addPath(UIBezierPath(roundedRect: inner, cornerRadius: 16).cgPath)
        ctx.fillPath()
        image.draw(in: inner.insetBy(dx: 18, dy: 18))
    }

    private static func drawPixel(on ctx: CGContext, size: CGSize, image: UIImage) {
        let rect = CGRect(x: 140, y: 180, width: size.width-280, height: size.height-360)
        // 背板
        ctx.setFillColor(UIColor.secondarySystemBackground.cgColor)
        ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 18).cgPath)
        ctx.fillPath()
        // 虚线边框
        ctx.setStrokeColor(UIColor.gray.withAlphaComponent(0.3).cgColor)
        ctx.setLineDash(phase: 0, lengths: [6,4])
        ctx.setLineWidth(2)
        ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 18).cgPath)
        ctx.strokePath()
        // 图像
        image.draw(in: rect.insetBy(dx: 16, dy: 16))
    }

    static func saveBadgeImages(image: UIImage, id: UUID) -> (imagePath: String, thumbPath: String)? {
        guard let data = image.pngData() else { return nil }
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RealityBadge", isDirectory: true)
        let dir = base.appendingPathComponent("Badges", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) { try? fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        let imgURL = dir.appendingPathComponent("\(id.uuidString).png")
        do { try data.write(to: imgURL) } catch { return nil }
        // 缩略图
        let thumb = resize(image: image, maxEdge: 300)
        guard let tData = thumb.pngData() else { return nil }
        let tURL = dir.appendingPathComponent("\(id.uuidString)_thumb.png")
        do { try tData.write(to: tURL) } catch { return nil }
        return (imgURL.path, tURL.path)
    }

    static func saveRaw(image: UIImage, mask: CGImage?, depth: CGImage?, id: UUID) -> (capturePath: String, maskPath: String?, depthPath: String?)? {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RealityBadge", isDirectory: true)
        let dir = base.appendingPathComponent("Raw", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) { try? fm.createDirectory(at: dir, withIntermediateDirectories: true) }

        guard let data = image.pngData() else { return nil }
        let capURL = dir.appendingPathComponent("\(id.uuidString)_capture.png")
        do { try data.write(to: capURL) } catch { return nil }

        var maskURL: URL? = nil
        if let m = mask, let ui = UIImage(cgImage: m).pngData() {
            let u = dir.appendingPathComponent("\(id.uuidString)_mask.png"); try? ui.write(to: u); maskURL = u
        }
        var depthURL: URL? = nil
        if let d = depth, let ui = UIImage(cgImage: d).pngData() {
            let u = dir.appendingPathComponent("\(id.uuidString)_depth.png"); try? ui.write(to: u); depthURL = u
        }
        return (capURL.path, maskURL?.path, depthURL?.path)
    }

    private static func resize(image: UIImage, maxEdge: CGFloat) -> UIImage {
        let w = image.size.width
        let h = image.size.height
        let longest = Swift.max(w, h)
        guard longest > 0 else { return image }
        let scale = min(1, maxEdge / longest)
        let size = CGSize(width: w*scale, height: h*scale)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        image.draw(in: CGRect(origin: .zero, size: size))
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return out ?? image
    }
}
