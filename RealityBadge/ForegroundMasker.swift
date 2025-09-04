import Foundation
import Vision
import CoreVideo
import CoreImage
import UIKit

enum ForegroundMasker {
    @available(iOS 17.0, *)
    static func mask(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        // 为保证编译稳定，这里先返回 nil（仍可用动态预览的轻视差）。
        // 如需启用，请按你的 Xcode SDK 中 VNForegroundInstanceMaskObservation 的 API 实现。
        // 示例：
        // let request = VNGenerateForegroundInstanceMaskRequest()
        // try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
        // if let obs = request.results?.first {
        //    let pb = try? obs.generateMaskedImage(ofInstances: obs.allInstances, from: pixelBuffer)
        //    // 将 pb 转 CGImage 返回
        // }
        return nil
    }

    static func image(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
