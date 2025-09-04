import Foundation
import CoreImage
import UIKit

enum DepthProcessor {
    static func layeredImages(image: UIImage, depth: CGImage, levels: Int = 4) -> [UIImage] {
        guard let baseCG = image.cgImage else { return [] }
        let ciImage = CIImage(cgImage: baseCG)
        let depthCI = CIImage(cgImage: depth)
        let context = CIContext()

        // 归一化深度（假设0..1），然后线性分层（可后续替换为直方图分位数）
        var outputs: [UIImage] = []
        for i in 0..<levels {
            let minT = Float(i) / Float(levels)
            let maxT = Float(i+1) / Float(levels)
            // mask = inRange(depth, minT, maxT)
            let clamp = CIFilter(name: "CIColorClamp", parameters: [
                kCIInputImageKey: depthCI,
                "inputMinComponents": CIVector(x: CGFloat(minT), y: CGFloat(minT), z: CGFloat(minT), w: 1),
                "inputMaxComponents": CIVector(x: CGFloat(maxT), y: CGFloat(maxT), z: CGFloat(maxT), w: 1)
            ])!.outputImage ?? depthCI
            let normalize = CIFilter(name: "CIColorMatrix", parameters: [
                kCIInputImageKey: clamp,
                "inputRVector": CIVector(x: 1/(CGFloat(maxT-minT)+0.0001), y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1/(CGFloat(maxT-minT)+0.0001), z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1/(CGFloat(maxT-minT)+0.0001), w: 0),
                "inputBiasVector": CIVector(x: -CGFloat(minT)/(CGFloat(maxT-minT)+0.0001), y: -CGFloat(minT)/(CGFloat(maxT-minT)+0.0001), z: -CGFloat(minT)/(CGFloat(maxT-minT)+0.0001), w: 0)
            ])!.outputImage ?? clamp
            // 内容与黑底混合
            let blend = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: ciImage.extent),
                kCIInputMaskImageKey: normalize
            ])!.outputImage ?? ciImage
            if let cg = context.createCGImage(blend, from: blend.extent) {
                outputs.append(UIImage(cgImage: cg))
            }
        }
        return outputs
    }
}

