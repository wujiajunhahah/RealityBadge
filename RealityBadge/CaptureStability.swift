import Foundation
import CoreGraphics

struct StabilityResult {
    let passed: Bool
    let stableCount: Int
    let hint: String
}

final class StabilityGate {
    private let requiredFrames: Int
    private let maxWindow: Int
    private let driftTolerance: CGFloat
    private var window: [CGFloat] = []

    init(requiredFrames: Int = 12, maxWindow: Int = 18, driftTolerance: CGFloat = 0.10) {
        self.requiredFrames = requiredFrames
        self.maxWindow = maxWindow
        self.driftTolerance = driftTolerance
    }

    func reset() { window.removeAll() }

    // 推入一帧，返回结果；不同模式传入不同阈值即可
    func push(scores: SemanticScores, fused: CGFloat, threshold: CGFloat, mode: RBValidationMode) -> StabilityResult {
        if window.count >= maxWindow { window.removeFirst() }
        window.append(fused)

        // 计算连续满足阈值的帧数
        var cnt = 0
        for v in window.reversed() {
            if v >= threshold { cnt += 1 } else { break }
        }

        // 漂移（max-min）太大视作不稳定
        let drift: CGFloat = (window.max() ?? 0) - (window.min() ?? 0)
        let passed = (cnt >= requiredFrames) && (drift <= driftTolerance)

        let hint: String
        if passed {
            hint = "已稳定识别，准备压印"
        } else if scores.objectConfidence < 0.28 {
            hint = "光线不足／主体不明显"
        } else if mode == .strict && scores.handObjectIoU < 0.22 {
            if scores.objectConfidence < 0.6 || scores.textImageSimilarity < 0.6 {
                hint = "请让手与目标更贴近"
            } else {
                hint = "再靠近一点点"
            }
        } else if drift > driftTolerance {
            hint = "画面不稳，请持稳 1 秒"
        } else if fused < threshold {
            hint = "再靠近一点点"
        } else {
            hint = "继续保持"
        }

        return StabilityResult(passed: passed, stableCount: cnt, hint: hint)
    }
}
