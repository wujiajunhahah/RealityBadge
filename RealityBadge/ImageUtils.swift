import UIKit
import CoreImage

// 通用：根据蒙版从原图裁剪主体，返回带透明通道的图像
func RBMakeSubjectCutout(image: UIImage, mask: UIImage) -> UIImage? {
    guard let ciImage = CIImage(image: image), let ciMask = CIImage(image: mask) else { return nil }
    let imgExtent = ciImage.extent
    let scaleX = imgExtent.width / ciMask.extent.width
    let scaleY = imgExtent.height / ciMask.extent.height
    let scaledMask = ciMask.transformed(by: .init(scaleX: scaleX, y: scaleY)).clamped(to: imgExtent)
    let clear = CIImage(color: .clear).cropped(to: imgExtent)
    let output = ciImage.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: clear,
        kCIInputMaskImageKey: scaledMask
    ])
    let context = CIContext()
    guard let cg = context.createCGImage(output, from: imgExtent) else { return nil }
    return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
}

