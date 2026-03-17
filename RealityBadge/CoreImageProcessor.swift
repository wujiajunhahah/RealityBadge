import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Core Image 图像处理
// 使用苹果原生 Core Image 框架

@available(iOS 13.0, *)
final class CoreImageProcessor {
    static let shared = CoreImageProcessor()
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    private init() {}

    // MARK: - 基础图像处理

    /// 调整图片亮度
    func adjustBrightness(image: UIImage, value: Double) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.brightness = value

        return render(filter: filter)
    }

    /// 调整图片对比度
    func adjustContrast(image: UIImage, value: Double) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.contrast = value

        return render(filter: filter)
    }

    /// 调整图片饱和度
    func adjustSaturation(image: UIImage, value: Double) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.saturation = value

        return render(filter: filter)
    }

    /// 应用模糊效果
    func applyBlur(image: UIImage, radius: Double = 10) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ciImage
        filter.radius = radius

        return render(filter: filter)
    }

    /// 应用锐化
    func applySharpen(image: UIImage, intensity: Double = 0.5) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = ciImage
        filter.sharpness = intensity

        return render(filter: filter)
    }

    /// 应用晕影效果
    func applyVignette(image: UIImage, intensity: Double = 0.5) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.vignette()
        filter.inputImage = ciImage
        filter.intensity = intensity

        return render(filter: filter)
    }

    /// 应用色差效果（复古照片）
    func applyVignette(image: UIImage, intensity: Double = 0.5) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.vignette()
        filter.inputImage = ciImage
        filter.intensity = intensity

        return render(filter: filter)
    }

    /// 应用色调效果
    func applyTonal(image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.photoEffectTonal()
        filter.inputImage = ciImage

        return render(filter: filter)
    }

    /// 应用黑白效果
    func applyMono(image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.photoEffectMono()
        filter.inputImage = ciImage

        return render(filter: filter)
    }

    /// 应用仿古效果
    func applySepia(image: UIImage, intensity: Double = 0.8) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.sepiaTone()
        filter.inputImage = ciImage
        filter.intensity = intensity

        return render(filter: filter)
    }

    // MARK: - 高级图像处理

    /// 应用液态玻璃效果
    func applyLiquidGlass(image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.glassLoupe()
        filter.inputImage = ciImage

        // 降低饱和度
        let saturationFilter = CIFilter.colorControls()
        saturationFilter.inputImage = filter.outputImage
        saturationFilter.saturation = 0.6

        // 增加亮度
        let brightnessFilter = CIFilter.colorControls()
        brightnessFilter.inputImage = saturationFilter.outputImage
        brightnessFilter.brightness = 0.05

        return render(filter: brightnessFilter)
    }

    /// 应用 3D 深度效果
    func applyDepthEffect(image: UIImage, depthMap: UIImage?) -> UIImage? {
        guard let ciImage = CIImage(image: image),
              let depthCIImage = depthMap.flatMap({ CIImage(image: $0) }) else {
            // 如果没有深度图，使用模拟效果
            return applySimulatedDepth(image: image)
        }

        // 使用深度图创建视差效果
        let filter = CIFilter.depthBlurEffect()
        filter.inputImage = ciImage
        filter.inputDepthMap = depthCIImage

        return render(filter: filter)
    }

    /// 应用模拟深度效果
    func applySimulatedDepth(image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // 创建径向渐变作为深度模拟
        let radialGradient = CIFilter.radialGradient()
        radialGradient.inputRadius = NSNumber(value: min(image.size.width, image.size.height) / 2)
        radialGradient.inputCenter = CIVector(x: image.size.width / 2, y: image.size.height / 2)
        radialGradient.inputColor0 = CIColor(red: 1, green: 1, blue: 1, alpha: 1)
        radialGradient.inputColor1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)

        // 混合原图和渐变
        let blendFilter = CIFilter.sourceOverCompositing()
        blendFilter.inputImage = radialGradient.outputImage
        blendFilter.inputBackgroundImage = ciImage

        return render(filter: blendFilter)
    }

    /// 应用边缘检测（用于主体提取）
    func detectEdges(image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.edges()
        filter.inputImage = ciImage

        return render(filter: filter)
    }

    /// 应用自适应阈值（用于分割）
    func applyAdaptiveThreshold(image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // 转换为灰度
        let monoFilter = CIFilter.photoEffectMono()
        monoFilter.inputImage = ciImage

        // 应用阈值
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = monoFilter.outputImage
        thresholdFilter.threshold = 0.5
        thresholdFilter.gradientImage = monoFilter.outputImage

        return render(filter: thresholdFilter)
    }

    /// 应用晕映效果
    func applyBloom(image: UIImage, intensity: Double = 1.0, radius: Double = 10) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.bloom()
        filter.inputImage = ciImage
        filter.inputIntensity = intensity
        filter.inputRadius = radius

        return render(filter: filter)
    }

    /// 应用景深效果
    func applyDepthOfField(image: UIImage, focusPoint: CGPoint = .zero) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter.bokehBlur()
        filter.inputImage = ciImage
        filter.inputRadius = 10.0
        filter.inputMaskImage = nil  // 如果有蒙版可以传入

        return render(filter: filter)
    }

    // MARK: - 预设效果

    /// 徽章预设效果
    enum BadgePreset: String, CaseIterable {
        case normal = "原图"
        case vintage = "复古"
        case dramatic = "戏剧"
        case soft = "柔光"
        case bw = "黑白"
        case vibrant = "鲜艳"

        @available(iOS 16.0, *)
        var icon: String {
            switch self {
            case .normal: return "photo"
            case .vintage: return "camera.meter"
            case .dramatic: return "camera.aperture"
            case .soft: return "circle.lefthalf.filled"
            case .bw: return "circle"
            case .vibrant: return "circle.circle"
            }
        }
    }

    /// 应用徽章预设
    func applyBadgePreset(image: UIImage, preset: BadgePreset) -> UIImage? {
        switch preset {
        case .normal:
            return image
        case .vintage:
            return applySepia(image: image)
                ?? applyVignette(image: image, intensity: 0.5)
        case .dramatic:
            return applyContrast(image: image, value: 1.4)
                ?? applyBloom(image: image, intensity: 1.5)
        case .soft:
            return applyBlur(image: image, radius: 3)
                ?? applyBrightness(image: image, value: 0.1)
        case .bw:
            return applyMono(image: image)
        case .vibrant:
            return adjustSaturation(image: image, value: 1.4)
                ?? applyContrast(image: image, value: 1.2)
        }
    }

    // MARK: - 辅助方法

    private func render(filter: CIFilter) -> UIImage? {
        guard let outputImage = filter.outputImage else { return nil }

        let extent = outputImage.extent

        // 使用 GPU 渲染
        if let cgImage = context.createCGImage(outputImage, from: extent) {
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        }

        return nil
    }
}

// MARK: - SwiftUI 集成

@available(iOS 13.0, *)
struct ImageProcessorView: View {
    let sourceImage: UIImage
    @State private var processedImage: UIImage?
    @State private var selectedPreset: CoreImageProcessor.BadgePreset = .normal

    var body: some View {
        VStack(spacing: 20) {
            // 预设选择器
            Picker("效果", selection: $selectedPreset) {
                ForEach(CoreImageProcessor.BadgePreset.allCases, id: \.self) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            // 图片预览
            GroupBox(label: {
                if let processed = processedImage {
                    Image(uiImage: processed)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(uiImage: sourceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            })

            // 应用按钮
            Button("应用效果") {
                applyPreset()
            }
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBlue))
            .clipShape(Capsule())
        }
        .padding()
        .onChange(of: selectedPreset) { _, _ in
            applyPreset()
        }
        .onAppear {
            processedImage = sourceImage
        }
    }

    private func applyPreset() {
        processedImage = CoreImageProcessor.shared.applyBadgePreset(
            image: sourceImage,
            preset: selectedPreset
        )
    }
}

#Preview {
    if let sampleImage = UIImage(systemName: "star.fill") {
        ImageProcessorView(sourceImage: sampleImage)
    }
}
