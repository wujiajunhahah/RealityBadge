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
                let indexTip = try firstHand.recognizedPoint(.indexFingerTip)
                let middleTip = try firstHand.recognizedPoint(.middleFingerTip)
                
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
        scores.textImageSimilarity = calculateSemanticSimilarity(for: pixelBuffer)
        
        // 如果有手势位置，计算交互分数
        if let handPos = previousHandPosition {
            scores.handObjectIoU = calculateHandObjectInteraction(handPos: handPos)
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
            
            completion(results)
        }
    }
    
    private func createMaskImage(from observation: VNSaliencyImageObservation) -> UIImage? {
        guard let pixelBuffer = observation.pixelBuffer else { return nil }
        
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
        guard let pixelBuffer = observation.pixelBuffer else { return 0 }
        
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
    
    private func calculateSemanticSimilarity(for pixelBuffer: CVPixelBuffer) -> CGFloat {
        // 模拟语义相似度计算
        // 实际项目中应该使用CLIP或其他多模态模型
        return CGFloat.random(in: 0.3...0.8)
    }
    
    private func simulateVLMRecognition() -> String {
        // 模拟VLM识别结果
        let objects = ["树木", "咖啡杯", "雨伞", "手机", "书本", "花朵", "钥匙", "眼镜"]
        return objects.randomElement() ?? "未知物体"
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
        let stride = max(1, width * height / 10000)
        
        for y in stride(from: 0, to: height, by: max(1, height / 100)) {
            for x in stride(from: 0, to: width, by: stride) {
                let pixel = Double(buffer[y * bytesPerRow + x])
                sum += pixel
                pixelCount += 1
            }
        }
        
        let mean = sum / Double(pixelCount)
        
        // 计算方差（用于判断是否有物体）
        for y in stride(from: 0, to: height, by: max(1, height / 100)) {
            for x in stride(from: 0, to: width, by: stride) {
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
