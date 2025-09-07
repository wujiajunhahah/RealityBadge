import SwiftUI
import UIKit

/// 液态玻璃效果 - 模拟iOS 26的新材质
@available(iOS 15.0, *)
struct LiquidGlassView: View {
    @State private var phase: CGFloat = 0
    @State private var rippleOffset: CGSize = .zero
    let glassOpacity: Double
    let blurRadius: Double
    
    init(opacity: Double = 0.8, blur: Double = 20) {
        self.glassOpacity = opacity
        self.blurRadius = blur
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            // iOS 17+的高级效果
            advancedGlass
        } else {
            // 降级版本
            basicGlass
        }
    }
    
    @ViewBuilder
    private var advancedGlass: some View {
        ZStack {
            // 基础玻璃层
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(glassOpacity)
            
            // 液态动画层
            GeometryReader { geometry in
                Canvas { context, size in
                    // 绘制液态效果
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    
                    for i in 0..<3 {
                        let offset = Double(i) * 0.3
                        let radius = min(size.width, size.height) * (0.3 + sin(phase + offset) * 0.1)
                        
                        context.opacity = 0.1
                        context.fill(
                            Circle().path(in: CGRect(
                                x: center.x - radius/2 + rippleOffset.width,
                                y: center.y - radius/2 + rippleOffset.height,
                                width: radius,
                                height: radius
                            )),
                            with: .linearGradient(
                                Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ]),
                                startPoint: CGPoint(x: 0, y: 0),
                                endPoint: CGPoint(x: 1, y: 1)
                            )
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            
            // 光晕效果
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .scaleEffect(1 + sin(phase) * 0.1)
                .blur(radius: 30)
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
    
    @ViewBuilder
    private var basicGlass: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(glassOpacity)
    }
}

/// 高级材质修饰符
struct AdvancedMaterial: ViewModifier {
    let style: MaterialStyle
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    enum MaterialStyle {
        case glass
        case frosted
        case acrylic
        case neumorphic
    }
    
    func body(content: Content) -> some View {
        content
            .background(materialBackground)
            .overlay(materialOverlay)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
                isPressed = true
                HapticEngine.tap()
            } onPressingChanged: { pressing in
                isPressed = pressing
            }
    }
    
    @ViewBuilder
    private var materialBackground: some View {
        switch style {
        case .glass:
            if #available(iOS 16.0, *) {
                LiquidGlassView()
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            
        case .frosted:
            Rectangle()
                .fill(.regularMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
        case .acrylic:
            Rectangle()
                .fill(.thinMaterial)
                .overlay(
                    ZStack {
                        if colorScheme == .dark {
                            Color.white.opacity(0.03)
                        } else {
                            Color.black.opacity(0.03)
                        }
                        
                        // 噪点纹理
                        NoiseTexture()
                            .opacity(0.02)
                    }
                )
            
        case .neumorphic:
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .black : Color(.systemGray4),
                    radius: isPressed ? 5 : 10,
                    x: isPressed ? 2 : 5,
                    y: isPressed ? 2 : 5
                )
                .shadow(
                    color: colorScheme == .dark ? Color(.systemGray4) : .white,
                    radius: isPressed ? 5 : 10,
                    x: isPressed ? -2 : -5,
                    y: isPressed ? -2 : -5
                )
        }
    }
    
    @ViewBuilder
    private var materialOverlay: some View {
        switch style {
        case .glass, .frosted, .acrylic:
            Rectangle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            
        case .neumorphic:
            EmptyView()
        }
    }
}

/// 噪点纹理生成器
struct NoiseTexture: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        // 创建噪点图层
        let noiseLayer = CALayer()
        noiseLayer.contents = generateNoiseImage()?.cgImage
        noiseLayer.contentsScale = UIScreen.main.scale
        view.layer.addSublayer(noiseLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let noiseLayer = uiView.layer.sublayers?.first {
            noiseLayer.frame = uiView.bounds
        }
    }
    
    private func generateNoiseImage() -> UIImage? {
        let size = CGSize(width: 128, height: 128)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        for x in 0..<Int(size.width) {
            for y in 0..<Int(size.height) {
                let gray = CGFloat.random(in: 0...1)
                context.setFillColor(UIColor(white: gray, alpha: 1.0).cgColor)
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}

// MARK: - 扩展
extension View {
    func advancedMaterial(_ style: AdvancedMaterial.MaterialStyle) -> some View {
        modifier(AdvancedMaterial(style: style))
    }
}

/// 动态模糊效果
struct DynamicBlur: ViewModifier {
    let radius: CGFloat
    let opaque: Bool
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .blur(radius: radius, opaque: opaque)
        } else {
            content
                .blur(radius: radius)
        }
    }
}

/// 高级阴影效果
struct AdvancedShadow: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .shadow(color: color.opacity(colorScheme == .dark ? 0.8 : 0.3), radius: radius, x: x, y: y)
                .shadow(color: color.opacity(0.1), radius: radius * 2, x: x * 2, y: y * 2)
        } else {
            content
                .shadow(color: color, radius: radius, x: x, y: y)
        }
    }
}