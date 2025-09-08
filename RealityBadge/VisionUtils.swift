import Foundation
import UIKit
import Vision
import CoreImage

enum VisionUtils {
    // Generate an object-focused mask using Vision's object detector fused with saliency.
    static func generateObjectMask(from image: UIImage, targetLabel: String?) -> UIImage? {
        guard let cg = image.cgImage else { return nil }

        // 1) Object detection
        let request = VNRecognizeObjectsRequest()
        request.minimumConfidence = 0.4
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        do { try handler.perform([request]) } catch { return nil }

        guard let objects = request.results as? [VNRecognizedObjectObservation], !objects.isEmpty else {
            // fallback to pure saliency
            return saliencyMask(from: image)
        }

        // 2) Choose best observation: prefer label matching target keyword, else highest confidence
        let targetLower = (targetLabel ?? "").lowercased()
        let pick: VNRecognizedObjectObservation = {
            if !targetLower.isEmpty {
                // simple matching across all labels
                if let match = objects.first(where: { obs in
                    guard let top = obs.labels.first else { return false }
                    let name = top.identifier.lowercased()
                    return name.contains(targetLower) || synonyms(for: targetLower).contains(where: { name.contains($0) })
                }) { return match }
            }
            return objects.max(by: { $0.confidence < $1.confidence })!
        }()

        // 3) Create a soft rounded-rect mask around the chosen bbox
        let size = CGSize(width: cg.width, height: cg.height)
        let bbox = denormalize(pick.boundingBox, in: size)

        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        UIColor.black.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        UIColor.white.setFill()
        let radius = min(bbox.width, bbox.height) * 0.12
        let path = UIBezierPath(roundedRect: bbox.insetBy(dx: -bbox.width*0.05, dy: -bbox.height*0.05), cornerRadius: radius)
        path.fill()
        let bboxMask = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let bboxMaskCI = bboxMask.flatMap(CIImage.init(image:)) else { return nil }

        // 4) Fuse with saliency to better approximate subject shape
        if let sal = saliencyMask(from: image), let salCI = CIImage(image: sal) {
            let imgExtent = salCI.extent
            let ciBbox = bboxMaskCI.transformed(by: .init(scaleX: imgExtent.width / bboxMaskCI.extent.width,
                                                         y: imgExtent.height / bboxMaskCI.extent.height))
            let fused = salCI.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: ciBbox])
            let ctx = CIContext()
            if let cgOut = ctx.createCGImage(fused, from: fused.extent) {
                return UIImage(cgImage: cgOut, scale: image.scale, orientation: image.imageOrientation)
            }
        }

        // fallback to bbox mask only
        return bboxMask
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

    private static func denormalize(_ rect: CGRect, in size: CGSize) -> CGRect {
        return CGRect(x: rect.origin.x * size.width,
                      y: (1 - rect.origin.y - rect.size.height) * size.height,
                      width: rect.size.width * size.width,
                      height: rect.size.height * size.height)
    }

    private static func synonyms(for label: String) -> [String] {
        // Minimal synonym list to link common user intents
        let map: [String: [String]] = [
            "computer": ["computer","laptop","pc","notebook","macbook","desktop"],
            "screen": ["screen","display","monitor","tv"],
            "ipad": ["ipad","tablet","pad"],
            "phone": ["iphone","phone","mobile"],
            "headphones": ["headphones","headset","earbuds","earphones","airpods"],
            "cup": ["cup","mug","bottle","tumbler","coffee"],
            "umbrella": ["umbrella"],
            "paper": ["paper","document","doc","sheet","page","book","notebook"]
        ]
        for (_, arr) in map { if arr.contains(where: { label.contains($0) }) { return arr } }
        return []
    }
}

