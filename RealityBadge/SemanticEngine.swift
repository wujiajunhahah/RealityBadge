import Foundation
import AVFoundation
import CoreVideo
import Vision
import CoreML
import SwiftUI
import UIKit

/// 增强的语义信号输出
struct SemanticScores {
    var objectConfidence: CGFloat   // 物体是否存在
    var handObjectIoU: CGFloat      // 手-物交互程度
    var textImageSimilarity: CGFloat// 文本-图像相似度（关键词）
    var subjectMask: UIImage?       // 主体分割蒙版
    var depthMap: UIImage?          // 深度图
    var semanticLabel: String?      // VLM识别的语义标签
}

/// 增强版语义引擎：集成VLM、主体分割、深度估计
final class SemanticEngine {
    private let keywords: [String]
    private let visionQueue = DispatchQueue(label: "rb.vision.queue")
    private var handPoseRequest: VNDetectHumanHandPoseRequest?
    private var saliencyRequest: VNGenerateAttentionBasedSaliencyImageRequest?
    private var classificationRequest: VNCoreMLRequest?
    private var previousHandPosition: CGPoint?
    // 缓存最近的异步语义结果（供下一帧合并）
    private var latestSemanticScores: SemanticScores?
    
    // 语义同义词表（中英混合），用于更稳的匹配
    // key 为规范类别名（用于 UI 显示/符号映射），values 为可匹配的同义词
    private let synonymMap: [String: Set<String>] = [
        // 屏幕/显示类
        "屏幕": ["screen","display","monitor","tv","lcd","led","oled","retina","computer screen","laptop screen"],
        // iPad/平板（也兼容 tablet）
        "iPad": ["ipad","tablet","pad","ipados"],
        // 耳机/耳塞
        "耳机": ["headphones","headset","earphones","earbuds","airpods","airpods pro","earpod"],
        // 水杯/杯子/马克杯
        "水杯": ["cup","mug","coffee cup","tea cup","tumbler","water cup","water bottle","bottle"],
        // 雨伞
        "雨伞": ["umbrella","parasol"],
        // 纸张/文件/文档/书页
        "纸张": ["paper","document","documents","doc","sheet","page","a4","letter","notebook","book","printout","receipt"]
    ]
    
    // 存储最近的帧用于处理
    private var latestPixelBuffer: CVPixelBuffer?
    private var processingInProgress = false
    
    init(targetKeywords: [String]) {
        self.keywords = targetKeywords
        setupVisionRequests()
    }
    
    private func setupVisionRequests() {
        // 手势检测
        handPoseRequest = VNDetectHumanHandPoseRequest { [weak self] request, error in
            guard let observations = request.results as? [VNHumanHandPoseObservation],
                  let firstHand = observations.first else { return }
            
            do {
                // 获取手掌中心点
                let thumbTip = try firstHand.recognizedPoint(.thumbTip)
                let indexTip = try firstHand.recognizedPoint(.indexTip)
                let middleTip = try firstHand.recognizedPoint(.middleTip)
                
                let centerX = (thumbTip.x + indexTip.x + middleTip.x) / 3
                let centerY = (thumbTip.y + indexTip.y + middleTip.y) / 3
                
                self?.previousHandPosition = CGPoint(x: centerX, y: centerY)
            } catch {
                // 忽略错误
            }
        }
        handPoseRequest?.maximumHandCount = 2
        
        // 主体分割（显著性检测）
        saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
    }
    
    func process(sampleBuffer: CMSampleBuffer) -> SemanticScores {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return .init(objectConfidence: 0, handObjectIoU: 0, textImageSimilarity: 0)
        }
        
        // 保存最新帧
        latestPixelBuffer = pixelBuffer
        
        var scores = SemanticScores(
            objectConfidence: 0,
            handObjectIoU: 0,
            textImageSimilarity: 0
        )
        
        // 异步执行Vision处理
        if !processingInProgress {
            processingInProgress = true
            processVisionRequests(pixelBuffer: pixelBuffer) { [weak self] results in
                self?.processingInProgress = false
                // 结果会在下一帧返回
            }
        }
        
        // 基础分析（快速响应）
        let basicScores = analyzeBasicFeatures(pixelBuffer: pixelBuffer)
        scores.objectConfidence = basicScores.objectConfidence
        // 结合“识别到的标签”与目标关键词/同义词做语义相似度
        scores.textImageSimilarity = calculateSemanticSimilarity()
        
        // 如果有手势位置，计算交互分数
        if let handPos = previousHandPosition {
            scores.handObjectIoU = calculateHandObjectInteraction(handPos: handPos)
        }
        
        // 合并最近一次Vision处理的异步结果（标签/蒙版/深度等），避免阻塞捕获队列
        if let cached = self.latestSemanticScores {
            scores.subjectMask = cached.subjectMask
            scores.depthMap = cached.depthMap
            scores.semanticLabel = cached.semanticLabel
            // 采用更保守/更高的物体置信度
            scores.objectConfidence = max(scores.objectConfidence, cached.objectConfidence)
        }
        
        return scores
    }
    
    private func processVisionRequests(pixelBuffer: CVPixelBuffer, completion: @escaping (SemanticScores) -> Void) {
        visionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 性能优化：降低图像分辨率
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            var results = SemanticScores(
                objectConfidence: 0,
                handObjectIoU: 0,
                textImageSimilarity: 0
            )
            
            // 性能优化：根据设备性能调整请求
            var requests: [VNRequest] = []
            
            if PerformanceConfig.enableComplexEffects {
                if let handReq = self.handPoseRequest {
                    requests.append(handReq)
                }
            }
            
            if let saliencyReq = self.saliencyRequest {
                requests.append(saliencyReq)
            }
            
            do {
                try requestHandler.perform(requests)
                
                // 处理主体分割结果
                if let saliencyResults = self.saliencyRequest?.results as? [VNSaliencyImageObservation],
                   let observation = saliencyResults.first {
                    // 性能优化：只在需要时创建蒙版
                    if PerformanceConfig.enableComplexEffects {
                        results.subjectMask = self.createMaskImage(from: observation)
                    }
                    results.objectConfidence = self.calculateObjectConfidence(from: observation)
                }
                
                // 模拟VLM识别（实际项目中接入真实API）
                results.semanticLabel = self.simulateVLMRecognition()
                
            } catch {
                print("Vision request failed: \(error)")
            }
            // 缓存结果供主循环合并
            self.visionQueue.async { [weak self] in
                self?.latestSemanticScores = results
            }
            completion(results)
        }
    }
    
    private func createMaskImage(from observation: VNSaliencyImageObservation) -> UIImage? {
        let pixelBuffer = observation.pixelBuffer
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        // 应用阈值滤镜来创建清晰的蒙版
        let thresholdFilter = CIFilter(name: "CIColorControls")
        thresholdFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        thresholdFilter?.setValue(2.0, forKey: kCIInputContrastKey)
        thresholdFilter?.setValue(0.5, forKey: kCIInputBrightnessKey)
        
        guard let outputImage = thresholdFilter?.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func calculateObjectConfidence(from observation: VNSaliencyImageObservation) -> CGFloat {
        // 基于显著性图的强度计算置信度
        let pixelBuffer = observation.pixelBuffer
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0 }
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var totalSaliency: Double = 0
        var pixelCount = 0
        
        for y in stride(from: 0, to: height, by: 10) {
            for x in stride(from: 0, to: width, by: 10) {
                let pixel = buffer[y * bytesPerRow + x]
                totalSaliency += Double(pixel) / 255.0
                pixelCount += 1
            }
        }
        
        return CGFloat(totalSaliency / Double(pixelCount))
    }
    
    private func calculateHandObjectInteraction(handPos: CGPoint) -> CGFloat {
        // 简化的交互计算
        // 实际项目中应该计算手和物体边界框的IOU
        let centerDistance = sqrt(pow(handPos.x - 0.5, 2) + pow(handPos.y - 0.5, 2))
        return max(0, 1.0 - centerDistance * 2)
    }
    
    private func calculateSemanticSimilarity() -> CGFloat {
        // 读取最近一次模拟/识别标签（英文更常见），并与目标关键词 + 同义词匹配
        // 真实项目：这里应使用 CLIP/LLM/VLM 的文本-图像相似度
        let label = lastSimulatedLabel?.lowercased() ?? ""
        if label.isEmpty { return 0.2 }

        // 将目标关键词统一小写
        let target = Set(keywords.map { $0.lowercased() })

        // 若目标关键词中任一出现在标签中，判为高匹配
        if target.contains(where: { label.contains($0) }) { return 0.9 }

        // 同义词匹配：若标签落入任何一个类别的同义词集合，也给较高分
        for (_, synonyms) in synonymMap {
            if synonyms.contains(where: { label.contains($0) }) {
                return 0.85
            }
        }

        // 关键词部分命中（例如单词重叠）给中等分
        let labelTokens = Set(label.split { !$0.isLetter }.map(String.init))
        if target.intersection(labelTokens).isEmpty == false { return 0.6 }

        return 0.25
    }
    
    private var lastSimulatedLabel: String?
    private func simulateVLMRecognition() -> String {
        // 更贴近你的需求：重点覆盖屏幕/iPad/耳机/水杯/雨伞/纸张等英文标签
        let focus = [
            "screen","display","monitor","ipad","tablet","headphones","earbuds","airpods",
            "cup","mug","water bottle","umbrella","paper","document","notebook","book"
        ]
        let label = focus.randomElement() ?? "object"
        lastSimulatedLabel = label
        return label
    }
    
    private func analyzeBasicFeatures(pixelBuffer: CVPixelBuffer) -> (objectConfidence: CGFloat, brightness: CGFloat) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        
        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return (0, 0)
        }
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var sum: Double = 0
        var variance: Double = 0
        var pixelCount = 0
        
        // 采样计算亮度和方差
        let strideValue = max(1, width * height / 10000)
        
        for y in stride(from: 0, to: height, by: max(1, height / 100)) {
            for x in stride(from: 0, to: width, by: strideValue) {
                let pixel = Double(buffer[y * bytesPerRow + x])
                sum += pixel
                pixelCount += 1
            }
        }
        
        let mean = sum / Double(pixelCount)
        
        // 计算方差（用于判断是否有物体）
        for y in stride(from: 0, to: height, by: max(1, height / 100)) {
            for x in stride(from: 0, to: width, by: strideValue) {
                let pixel = Double(buffer[y * bytesPerRow + x])
                variance += pow(pixel - mean, 2)
            }
        }
        
        variance = variance / Double(pixelCount)
        
        // 方差越大，越可能有物体
        let objectConfidence = min(1.0, variance / 5000.0)
        let brightness = mean / 255.0
        
        return (CGFloat(objectConfidence), CGFloat(brightness))
    }
    
    // 生成深度图（模拟）
    func generateDepthMap(from image: UIImage) -> UIImage? {
        // 实际项目中应该使用MiDaS或其他深度估计模型
        // 这里创建一个简单的径向渐变作为演示
        
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let colors = [UIColor.white.cgColor, UIColor.black.cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colorLocations: [CGFloat] = [0.0, 1.0]
        
        guard let gradient = CGGradient(colorsSpace: colorSpace,
                                       colors: colors as CFArray,
                                       locations: colorLocations) else { return nil }
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2
        
        context.drawRadialGradient(gradient,
                                  startCenter: center,
                                  startRadius: 0,
                                  endCenter: center,
                                  endRadius: radius,
                                  options: [])
        
        let depthImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return depthImage
    }
}
