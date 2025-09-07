import UIKit
import CoreHaptics
import AudioToolbox

/// 高级触觉引擎 - WWDC级别的触觉体验
final class HapticEngine {
    static let shared = HapticEngine()
    
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    
    private init() {
        setupHapticEngine()
    }
    
    private func setupHapticEngine() {
        // 检查设备是否支持CoreHaptics
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsHaptics = false
            return
        }
        
        do {
            engine = try CHHapticEngine()
            supportsHaptics = true
            
            // 设置引擎停止处理程序
            engine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
            }
            
            // 设置引擎重置处理程序
            engine?.resetHandler = { [weak self] in
                self?.startEngine()
            }
            
            startEngine()
            
        } catch {
            print("Failed to create haptic engine: \(error)")
            supportsHaptics = false
        }
    }
    
    private func startEngine() {
        engine?.start { error in
            if let error = error {
                print("Failed to start haptic engine: \(error)")
            }
        }
    }
    
    // MARK: - 预定义的触觉模式
    
    /// 捕获成功 - 模拟相机快门的物理感觉
    func captureSuccess() {
        guard supportsHaptics else {
            // 降级到简单反馈
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        
        do {
            let pattern = try createCapturePattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            // 降级处理
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    /// 识别到物体 - 渐进式的触觉反馈
    func objectDetected(confidence: Float) {
        guard supportsHaptics else {
            if confidence > 0.8 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            return
        }
        
        do {
            let pattern = try createDetectionPattern(intensity: confidence)
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    /// 3D交互 - 精细的触觉响应
    func interact3D(intensity: Float = 0.5) {
        guard supportsHaptics else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return
        }
        
        do {
            let pattern = try create3DInteractionPattern(intensity: intensity)
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
    
    /// 徽章解锁 - 庆祝性的触觉序列
    func badgeUnlocked() {
        guard supportsHaptics else {
            // 降级到连续的反馈
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            return
        }
        
        do {
            let pattern = try createUnlockPattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    /// 液态玻璃过渡 - 流动感的触觉
    func liquidTransition() {
        guard supportsHaptics else { return }
        
        do {
            let pattern = try createLiquidPattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            // 静默失败
        }
    }
    
    // MARK: - 触觉模式创建
    
    private func createCapturePattern() throws -> CHHapticPattern {
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        
        // 模拟快门按下
        let event1 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [sharpness, intensity],
            relativeTime: 0
        )
        
        // 模拟快门释放
        let event2 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
            ],
            relativeTime: 0.1
        )
        
        return try CHHapticPattern(events: [event1, event2], parameters: [])
    }
    
    private func createDetectionPattern(intensity: Float) throws -> CHHapticPattern {
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: intensity * 0.5)
        let hapticIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [sharpness, hapticIntensity],
            relativeTime: 0,
            duration: 0.1
        )
        
        return try CHHapticPattern(events: [event], parameters: [])
    }
    
    private func create3DInteractionPattern(intensity: Float) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // 创建波浪式的触觉反馈
        for i in 0..<3 {
            let time = TimeInterval(i) * 0.05
            let eventIntensity = intensity * (1.0 - Float(i) * 0.3)
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: eventIntensity)
                ],
                relativeTime: time
            )
            events.append(event)
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func createUnlockPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // 渐进式的庆祝触觉
        for i in 0..<5 {
            let time = TimeInterval(i) * 0.1
            let intensity = 0.3 + Float(i) * 0.15
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(i) * 0.2),
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
                ],
                relativeTime: time
            )
            events.append(event)
        }
        
        // 最后的重音
        let finalEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            ],
            relativeTime: 0.6
        )
        events.append(finalEvent)
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func createLiquidPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // 流动的连续触觉
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
            ],
            relativeTime: 0,
            duration: 0.5
        )
        events.append(event)
        
        // 动态参数曲线
        let parameter = CHHapticDynamicParameter(
            parameterID: .hapticIntensityControl,
            value: 0.3,
            relativeTime: 0
        )
        
        let parameter2 = CHHapticDynamicParameter(
            parameterID: .hapticIntensityControl,
            value: 0.0,
            relativeTime: 0.5
        )
        
        return try CHHapticPattern(
            events: events,
            parameters: [parameter, parameter2]
        )
    }
}

// MARK: - 简化的调用接口
extension HapticEngine {
    
    /// 轻触反馈
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    /// 选择反馈
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    /// 中等反馈
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    /// 通知反馈
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}