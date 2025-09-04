import Foundation
import CoreML
import Vision
import CoreVideo

// 可选的 VLM（如 MobileCLIP）适配器：
// 如果 Bundle 中包含图像/文本编码器模型（.mlmodelc），则用余弦相似度计算图像-文本相似度。
// 命名约定（可自定义）：
// - 图像模型：MobileCLIP_ImageEncoder.mlmodelc（输入名优先取 "image"，输出名优先取 "embedding"）
// - 文本模型：MobileCLIP_TextEncoder.mlmodelc（输入名优先取 "text"，输出名优先取 "embedding"）
// 如未找到或 I/O 规格不匹配，则自动禁用，返回 nil。

final class VLMSimilarity {
    private let imageModel: MLModel?
    private let textModel: MLModel?

    private let imageInputName: String?
    private let imageOutputName: String?
    private let textInputName: String?
    private let textOutputName: String?

    init() {
        // 优先按约定名加载；否则自动扫描 bundle 内任何 .mlmodelc，匹配一个图像编码器 + 一个文本编码器
        func loadModel(named name: String) -> MLModel? {
            guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else { return nil }
            return try? MLModel(contentsOf: url)
        }

        var im = loadModel(named: "MobileCLIP_ImageEncoder")
        var tm = loadModel(named: "MobileCLIP_TextEncoder")

        if im == nil || tm == nil {
            if let urls = Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil) {
                for u in urls {
                    if let m = try? MLModel(contentsOf: u) {
                        let inputs = m.modelDescription.inputDescriptionsByName
                        // 粗略判断：存在 image 或 pixelBuffer 输入 → 视为图像编码器；存在 string 输入 → 文本编码器
                        let hasImage = inputs.values.contains(where: { d in
                            d.type == .image || d.type == .multiArray || d.type == .dictionary
                        })
                        let hasString = inputs.values.contains(where: { d in d.type == .string })
                        if im == nil && hasImage { im = m }
                        if tm == nil && hasString { tm = m }
                    }
                }
            }
        }

        imageModel = im
        textModel = tm

        func preferredIO(_ model: MLModel, inputHints: [String], outputHints: [String]) -> (String?, String?) {
            let inNames = model.modelDescription.inputDescriptionsByName.keys
            let outNames = model.modelDescription.outputDescriptionsByName.keys
            let inName = inputHints.first(where: { inNames.contains($0) }) ?? inNames.first
            let outName = outputHints.first(where: { outNames.contains($0) }) ?? outNames.first
            return (inName, outName)
        }

        if let im {
            let (iin, iout) = preferredIO(im, inputHints: ["image", "pixelValue"], outputHints: ["embedding", "imageEmbedding", "pooled_output", "last_hidden_state"])
            imageInputName = iin; imageOutputName = iout
        } else { imageInputName = nil; imageOutputName = nil }

        if let tm {
            let (tin, tout) = preferredIO(tm, inputHints: ["text", "string", "tokens"], outputHints: ["embedding", "textEmbedding", "pooled_output", "last_hidden_state"])
            textInputName = tin; textOutputName = tout
        } else { textInputName = nil; textOutputName = nil }

        #if DEBUG
        if isAvailable {
            print("[VLM] Encoders detected. imageIn=\(imageInputName ?? "-") textIn=\(textInputName ?? "-")")
        } else {
            print("[VLM] Not available. Put .mlmodel files into RealityBadge/Models (we compile at build).")
        }
        #endif
    }

    var isAvailable: Bool { imageModel != nil && textModel != nil && imageInputName != nil && imageOutputName != nil && textInputName != nil && textOutputName != nil }

    func similarity(pixelBuffer: CVPixelBuffer, texts: [String]) -> CGFloat? {
        guard isAvailable, let imageModel, let textModel, let iIn = imageInputName, let iOut = imageOutputName, let tIn = textInputName, let tOut = textOutputName else {
            #if DEBUG
            print("[VLM] Not available - models not loaded properly")
            #endif
            return nil
        }

        // 1) 图像向量
        let imgFV: [Float]
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [iIn: MLFeatureValue(pixelBuffer: pixelBuffer)])
            let out = try imageModel.prediction(from: input)
            guard let v = out.featureValue(for: iOut)?.multiArrayValue else { return nil }
            imgFV = v.toArray()
        } catch { return nil }

        // 2) 文本向量（取最大相似度）
        var best: Float = -1
        for t in texts {
            // 文本模型需要 String 输入；若不是则跳过
            guard textModel.modelDescription.inputDescriptionsByName[tIn]?.type == .string else { return nil }
            do {
                let input = try MLDictionaryFeatureProvider(dictionary: [tIn: MLFeatureValue(string: t)])
                let out = try textModel.prediction(from: input)
                guard let v = out.featureValue(for: tOut)?.multiArrayValue else { continue }
                let sim = cosine(imgFV, v.toArray())
                if sim > best { best = sim }
            } catch { continue }
        }
        if best < 0 { return nil }
        // 归一到 0..1（CLIP 余弦多在 [-1,1]）
        let n = max(0, min(1, (best + 1) * 0.5))

        #if DEBUG
        print("[VLM] Similarity calculated: raw=\(String(format: "%.3f", best)) normalized=\(String(format: "%.3f", n)) for texts: \(texts)")
        #endif

        return CGFloat(n)
    }
}

private func cosine(_ a: [Float], _ b: [Float]) -> Float {
    let n = min(a.count, b.count)
    if n == 0 { return -1 }
    var dot: Float = 0, na: Float = 0, nb: Float = 0
    for i in 0..<n { dot += a[i]*b[i]; na += a[i]*a[i]; nb += b[i]*b[i] }
    if na == 0 || nb == 0 { return -1 }
    return dot / (sqrt(na) * sqrt(nb))
}

private extension MLMultiArray {
    func toArray() -> [Float] {
        let p = UnsafeMutablePointer<Float>(OpaquePointer(self.dataPointer))
        return Array(UnsafeBufferPointer(start: p, count: self.count))
    }
}
