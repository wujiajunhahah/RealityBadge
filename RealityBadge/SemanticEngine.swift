import Foundation
import AVFoundation
import CoreVideo
import Vision
import CoreML
import SwiftUI

/// 统一的语义信号输出（未来把 VLM/分割/手势接进来）
struct SemanticScores {
    var objectConfidence: CGFloat   // 物体是否存在
    var handObjectIoU: CGFloat      // 手-物交互程度
    var textImageSimilarity: CGFloat// 文本-图像相似度（关键词）
}

/// 轻量占位引擎：用亮度估计生成可视化的三路分数，便于联调
/// 后续可把 brightness 替换为：
/// - objectConfidence: 主体分割/目标检测结果
/// - handObjectIoU: 手势关键点 + 目标区域 IOU
/// - textImageSimilarity: MobileCLIP 相似度
final class SemanticEngine {
    private let keywords: [String]
    private var ema: Double = 0 // brightness EMA

    init(targetKeywords: [String]) {
        self.keywords = targetKeywords
    }

    func process(sampleBuffer: CMSampleBuffer) -> SemanticScores {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return .init(objectConfidence: 0, handObjectIoU: 0, textImageSimilarity: 0)
        }
        CVPixelBufferLockBaseAddress(pixel, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixel, .readOnly) }

        // 仅用亮度平滑占位，确保可运行与可视化（后面替换为真模型）
        let w = CVPixelBufferGetWidthOfPlane(pixel, 0)
        let h = CVPixelBufferGetHeightOfPlane(pixel, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixel, 0)
        guard let baseAddr = CVPixelBufferGetBaseAddressOfPlane(pixel, 0) else {
            return .init(objectConfidence: 0, handObjectIoU: 0, textImageSimilarity: 0)
        }
        let ptr = baseAddr.assumingMemoryBound(to: UInt8.self)

        var sum: Double = 0
        var count = 0
        let strideY = max(1, h / 120)
        let strideX = max(1, w * h / 8000)
        for y in stride(from: 0, to: h, by: strideY) {
            let row = ptr + y * bytesPerRow
            for x in stride(from: 0, to: w, by: strideX) {
                sum += Double(row[x])
                count += 1
            }
        }
        let mean = (count > 0) ? sum / Double(count) : 0
        let alpha = 0.06
        ema = alpha * mean + (1 - alpha) * ema
        let norm = CGFloat(min(1.0, max(0.0, ema / 255.0)))

        // 用同一亮度信号分别映射三路分数，便于你先看动效
        return SemanticScores(
            objectConfidence: norm,
            handObjectIoU: pow(norm, 0.8),   // 稍微偏高一点
            textImageSimilarity: sqrt(norm)  // 稍偏低，模拟不同来源
        )
    }
}
