import Foundation
import AVFoundation
import CoreVideo
import Vision
import ImageIO
import SwiftUI

// 输出三路真实信号：物体、互动、语义（基于标签匹配）
struct SemanticScores {
    var objectConfidence: CGFloat   // 匹配目标物体的置信度
    var handObjectIoU: CGFloat      // 手-物重叠/接近度
    var textImageSimilarity: CGFloat// 关键词与识别标签的语义接近度（简化为标签匹配分）
}

final class SemanticEngine {
    private let keywords: [String]
    private let keywordsNorm: [String]
    private let synonyms: [String: [String]]
    private let vlm = VLMSimilarity()

    // 复用 Vision 请求（减少分配）。此实现使用图像分类 + 手势 + 人脸
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 2
        return r
    }()
    private let classRequest = VNClassifyImageRequest()
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private var lastBestLabelInternal: String?
    private var lastClasses: [VNClassificationObservation] = []
    private let classEveryN = 3
    private let faceEveryN = 4

    private var frameCount = 0

    init(targetKeywords: [String]) {
        self.keywords = targetKeywords
        self.keywordsNorm = targetKeywords.map { SemanticEngine.normalize($0) }
        self.synonyms = SemanticEngine.defaultSynonyms()
        // 无需对象检测请求；使用图像分类匹配近似 objectConfidence
    }

    func process(sampleBuffer: CMSampleBuffer) -> SemanticScores {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return .init(objectConfidence: 0, handObjectIoU: 0, textImageSimilarity: 0)
        }

        // 降采样：每 2 帧跑一次完整 Vision，其他帧复用结果（这里简单返回上次结果）
        frameCount += 1

        // 执行 Vision（节流执行，减少每帧开销）
        let handler = VNImageRequestHandler(cvPixelBuffer: pixel, orientation: .right, options: [:])
        var reqs: [VNRequest] = []
        if frameCount % classEveryN == 0 { reqs.append(classRequest) }
        if frameCount % faceEveryN == 0 { reqs.append(faceRequest) }
        reqs.append(handRequest)
        if !reqs.isEmpty {
            do { try handler.perform(reqs) } catch { /* 忽略单帧错误 */ }
        }

        // 图像分类结果（若本帧未跑分类，复用上次结果）
        let classifications: [VNClassificationObservation]
        if frameCount % classEveryN == 0 {
            classifications = (classRequest.results as? [VNClassificationObservation]) ?? lastClasses
            lastClasses = classifications
        } else {
            classifications = lastClasses
        }
        if let first = classifications.first { lastBestLabelInternal = first.identifier }
        let objectConf: CGFloat = classificationMatchConfidence(classifications)
        #if DEBUG
        if !classifications.isEmpty {
            let top = classifications.prefix(3).map { "\($0.identifier)(\(String(format: "%.2f", $0.confidence)))" }.joined(separator: ", ")
            print("[Vision] classes: \(top)  · objectConf=\(String(format: "%.2f", objectConf))")
        } else {
            print("[Vision] classes: none")
        }
        #endif

        // 解析手部，构造手的包围盒（合并双手）
        let hands = (handRequest.results as? [VNHumanHandPoseObservation]) ?? []
        let handBox = mergedHandBoundingBox(hands)

        // 互动程度：IoU + 邻近增强
        let interaction: CGFloat = {
            // 无对象框时，暂不计算互动（后续可引入分割掩膜/目标检测再恢复）
            guard let _ = handBox else { return 0 }
            return 0
        }()

        // 文本-图像相似度：分类匹配 + 可选 VLM
        var textSim: CGFloat = similarityFromClassification(classifications)
        // 若可用，使用 VLM（如 MobileCLIP）计算文本-图像相似度（取多个关键词最大值）
        if let sim = vlm.similarity(pixelBuffer: pixel, texts: keywords) {
            #if DEBUG
            print("[SemanticEngine] VLM similarity: \(String(format: "%.3f", sim)) for keywords: \(keywords)")
            #endif
            textSim = max(textSim, sim)
        } else {
            #if DEBUG
            print("[SemanticEngine] VLM not available, using Vision only")
            #endif
        }

        // 特殊类增强：笑 / 黑衣服 / 月亮
        let faces = faceRequest.results as? [VNFaceObservation]
        let smileBoost = smileScore(from: faces)
        // 无对象框，人物区域估计暂置空
        let personBox: CGRect? = nil
        let blackBoost = blackClothesScore(in: pixel, personBox: personBox)
        let moonBoost = moonScore(from: classifications)

        var finalObj = objectConf
        if containsKeyword("笑") || containsKeyword("smile") { finalObj = max(finalObj, smileBoost) }
        if containsKeyword("黑衣服") || containsKeyword("black clothes") { finalObj = max(finalObj, blackBoost) }
        if containsKeyword("月亮") || containsKeyword("moon") { finalObj = max(finalObj, moonBoost) }

        return .init(objectConfidence: finalObj, handObjectIoU: interaction, textImageSimilarity: textSim)
    }

    // MARK: - Helpers
    func bestLabel() -> String? { lastBestLabelInternal }
    // 从图像分类结果中取与关键词/同义词最佳匹配的置信度
    private func classificationMatchConfidence(_ classes: [VNClassificationObservation]) -> CGFloat {
        var best: CGFloat = 0
        for c in classes {
            let n = SemanticEngine.normalize(c.identifier)
            if keywordsNorm.contains(n) || synonymsMatch(n) {
                best = max(best, CGFloat(c.confidence))
            }
        }
        return best
    }

    private func similarityFromClassification(_ classes: [VNClassificationObservation]) -> CGFloat {
        var best: CGFloat = 0
        for c in classes {
            best = max(best, fuzzySim(c.identifier) * CGFloat(c.confidence))
        }
        return min(1, best * 0.9)
    }

    private func synonymsMatch(_ normLabel: String) -> Bool {
        for k in keywordsNorm {
            if let syns = synonyms[k], syns.contains(normLabel) { return true }
        }
        return false
    }

    private func mergedHandBoundingBox(_ hands: [VNHumanHandPoseObservation]) -> CGRect? {
        var rect: CGRect?
        for h in hands {
            guard let box = handBoundingBox(observation: h) else { continue }
            rect = rect?.union(box) ?? box
        }
        return rect
    }

    private func handBoundingBox(observation: VNHumanHandPoseObservation) -> CGRect? {
        // 利用关键点包围盒
        guard let all = try? observation.recognizedPoints(.all) else { return nil }
        var minX: CGFloat = 1, minY: CGFloat = 1, maxX: CGFloat = 0, maxY: CGFloat = 0
        var has = false
        for (_, p) in all where p.confidence > 0.1 {
            has = true
            minX = min(minX, p.location.x)
            minY = min(minY, p.location.y)
            maxX = max(maxX, p.location.x)
            maxY = max(maxY, p.location.y)
        }
        if !has { return nil }
        let pad: CGFloat = 0.05
        let r = CGRect(x: max(0, minX - pad), y: max(0, minY - pad), width: min(1, maxX + pad) - max(0, minX - pad), height: min(1, maxY + pad) - max(0, minY - pad))
        return r
    }

    private func fuzzySim(_ label: String) -> CGFloat {
        let n = SemanticEngine.normalize(label)
        var best: CGFloat = 0
        for k in keywordsNorm {
            let sim = jaccard(n, k)
            if sim > best { best = sim }
        }
        return best
    }

    private func jaccard(_ a: String, _ b: String) -> CGFloat {
        let sa = Set(a.split(separator: " "))
        let sb = Set(b.split(separator: " "))
        let inter = sa.intersection(sb).count
        let uni = sa.union(sb).count
        if uni == 0 { return 0 }
        return CGFloat(Double(inter) / Double(uni))
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
    }

    private static func defaultSynonyms() -> [String: [String]] {
        var map: [String: [String]] = [:]
        func add(_ key: String, _ values: [String]) { map[normalize(key), default: []] += values.map { normalize($0) } }

        // 基础
        add("tree", ["tree", "palm tree", "plant"])
        add("umbrella", ["umbrella"])
        add("door", ["door", "gate"])
        add("cat", ["cat", "kitten"])
        add("dog", ["dog", "puppy"])

        // 用户词汇
        // 水杯：按你的要求移除 cup/mug，偏向 bottle
        add("水杯", ["bottle", "water bottle", "drinking bottle"]) // 不含 cup/mug
        add("杯子", ["bottle", "water bottle"]) // 别名也不含 cup

        // 屏幕 / 电脑
        add("屏幕", ["screen", "monitor", "display", "television", "tv"]) 
        add("screen", ["screen", "monitor", "display"]) 
        add("电脑", ["computer", "laptop", "desktop", "notebook", "pc", "macbook"]) 
        add("computer", ["computer", "laptop", "desktop"]) 

        add("手表", ["watch", "wristwatch"])
        add("watch", ["watch", "wristwatch"]) // 英文入口

        add("手机", ["cell phone", "mobile phone", "phone", "telephone", "smartphone"])
        add("phone", ["cell phone", "mobile phone", "phone", "smartphone"])

        add("人", ["person", "human", "man", "woman", "boy", "girl"])
        add("person", ["person", "human"]) // 英文入口

        add("笑", ["smile", "smiling", "happy"])
        add("微笑", ["smile"]) // 别名

        add("黑衣服", ["black clothes", "black shirt", "black t-shirt", "clothes", "person"]) // 需配合人框+亮度
        add("black clothes", ["black shirt", "black t-shirt"]) // 英文入口

        add("月亮", ["moon", "night sky", "full moon", "crescent"])
        add("moon", ["moon", "night sky", "full moon", "crescent"]) // 英文入口

        return map
    }

    private func containsKeyword(_ s: String) -> Bool {
        let n = SemanticEngine.normalize(s)
        return keywordsNorm.contains(n)
    }

    // MARK: - 特征分数
    private func smileScore(from faces: [VNFaceObservation]?) -> CGFloat {
        guard let faces, !faces.isEmpty else { return 0 }
        // 暂时简化smile检测，返回固定值或基于其他特征
        // TODO: 修复VNFaceLandmarks的mouth访问问题
        return 0.5 // 临时返回值
    }

    private func blackClothesScore(in pixel: CVPixelBuffer, personBox: CGRect?) -> CGFloat {
        guard let box = personBox else { return 0 }
        CVPixelBufferLockBaseAddress(pixel, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixel, .readOnly) }
        let w = CVPixelBufferGetWidthOfPlane(pixel, 0)
        let h = CVPixelBufferGetHeightOfPlane(pixel, 0)
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixel, 0) else { return 0 }
        let bpr = CVPixelBufferGetBytesPerRowOfPlane(pixel, 0)
        let p = base.assumingMemoryBound(to: UInt8.self)

        let bx = max(0, min(1, box.origin.x))
        let by = max(0, min(1, box.origin.y))
        let bw = max(0, min(1, box.width))
        let bh = max(0, min(1, box.height))
        let rx0 = Int(CGFloat(w) * bx)
        let ry0 = Int(CGFloat(h) * (1 - (by + bh)))
        let rw = max(4, Int(CGFloat(w) * bw))
        let rh = max(4, Int(CGFloat(h) * bh / 2))

        var sum: Double = 0
        var cnt: Int = 0
        let stepY = max(1, rh / 60)
        let stepX = max(1, rw / 80)
        for yy in stride(from: 0, to: rh, by: stepY) {
            let row = p + (ry0 + yy) * bpr
            for xx in stride(from: 0, to: rw, by: stepX) {
                sum += Double(row[rx0 + xx])
                cnt += 1
            }
        }
        if cnt == 0 { return 0 }
        let mean = sum / Double(cnt) / 255.0
        let darkness = max(0, 1 - CGFloat(mean) * 1.2)
        return min(1, darkness)
    }

    private func moonScore(from classes: [VNClassificationObservation]) -> CGFloat {
        var best: CGFloat = 0
        for c in classes {
            let id = SemanticEngine.normalize(c.identifier)
            if id.contains("moon") || id.contains("night sky") || id.contains("full moon") || id.contains("crescent") {
                best = max(best, CGFloat(c.confidence))
            }
        }
        return best
    }
}

// IoU for normalized rects (Vision coordinates 0..1)
private func iouRect(_ a: CGRect, _ b: CGRect) -> CGFloat {
    let inter = a.intersection(b)
    if inter.isNull || inter.isEmpty { return 0 }
    let ia = inter.width * inter.height
    let ua = a.width * a.height + b.width * b.height - ia
    if ua <= 0 { return 0 }
    return ia / ua
}
