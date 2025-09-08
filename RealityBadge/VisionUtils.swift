import Foundation
import UIKit
import Vision
import CoreImage

enum VisionUtils {
    // Generate a subject mask using saliency only (compatible with wider SDKs).
    // targetLabel is currently unused but kept for API stability.
    static func generateObjectMask(from image: UIImage, targetLabel: String?) -> UIImage? {
        // Prefer advanced Apple Vision object recognition when enabled at compile time
        // and available at runtime; otherwise fall back to saliency.
#if USE_VN_OBJECTS
        if #available(iOS 17.0, *), let objMask = objectMaskUsingVN(image: image, targetLabel: targetLabel) {
            return objMask
        }
#endif
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

#if USE_VN_OBJECTS
import CoreGraphics
@available(iOS 17.0, *)
private func objectMaskUsingVN(image: UIImage, targetLabel: String?) -> UIImage? {
    guard let cg = image.cgImage else { return nil }
    let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
    let request = VNRecognizeObjectsRequest()
    request.minimumConfidence = 0.4
    do { try handler.perform([request]) } catch { return nil }
    guard let objects = request.results as? [VNRecognizedObjectObservation], !objects.isEmpty else { return nil }

    let targetLower = (targetLabel ?? "").lowercased()
    let chosen: VNRecognizedObjectObservation = {
        if !targetLower.isEmpty {
            if let match = objects.first(where: { obs in
                guard let top = obs.labels.first else { return false }
                let name = top.identifier.lowercased()
                return name.contains(targetLower)
            }) { return match }
        }
        return objects.max(by: { $0.confidence < $1.confidence })!
    }()

    // Build a soft mask from the bounding box
    let size = CGSize(width: cg.width, height: cg.height)
    let rect = CGRect(x: chosen.boundingBox.origin.x * size.width,
                      y: (1 - chosen.boundingBox.origin.y - chosen.boundingBox.height) * size.height,
                      width: chosen.boundingBox.width * size.width,
                      height: chosen.boundingBox.height * size.height)

    UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
    guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
    UIColor.black.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
    UIColor.white.setFill(); UIBezierPath(roundedRect: rect.insetBy(dx: -rect.width*0.05, dy: -rect.height*0.05), cornerRadius: min(rect.width, rect.height)*0.12).fill()
    let mask = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return mask
}
#endif
