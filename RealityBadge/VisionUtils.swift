import Foundation
import UIKit
import Vision
import CoreImage

enum VisionUtils {
    // Generate a subject mask using saliency only (compatible with wider SDKs).
    // targetLabel is currently unused but kept for API stability.
    static func generateObjectMask(from image: UIImage, targetLabel: String?) -> UIImage? {
        return saliencyMask(from: image)
    }

    private static func saliencyMask(from image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let req = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        do { try handler.perform([req]) } catch { return nil }
        guard let sal = req.results?.first as? VNSaliencyImageObservation else { return nil }
        let ci = CIImage(cvPixelBuffer: sal.pixelBuffer)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 2.4
            ])
        let ctx = CIContext()
        if let cgOut = ctx.createCGImage(ci, from: ci.extent) {
            return UIImage(cgImage: cgOut, scale: image.scale, orientation: image.imageOrientation)
        }
        return nil
    }

    // Helpers removed (object detector not used to maximize SDK compatibility)
}
