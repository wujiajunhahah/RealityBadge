import SwiftUI

/// 缩放按钮样式 - 带触觉反馈
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    HapticEngine.tap()
                }
            }
    }
}

/// 弹性按钮样式
struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .rotationEffect(.degrees(configuration.isPressed ? 2 : 0))
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// 玻璃按钮样式
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Group {
                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 涟漪效果按钮
struct RippleButton: View {
    let action: () -> Void
    let label: () -> AnyView
    
    @State private var ripples: [Ripple] = []
    
    struct Ripple: Identifiable {
        let id = UUID()
        let position: CGPoint
        let startTime: Date
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 涟漪层
                ForEach(ripples) { ripple in
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 0, height: 0)
                        .position(ripple.position)
                        .modifier(RippleModifier(startTime: ripple.startTime))
                }
                
                // 按钮内容
                Button(action: {
                    action()
                    HapticEngine.tap()
                }) {
                    label()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onTapGesture(coordinateSpace: .local) { location in
                let newRipple = Ripple(position: location, startTime: Date())
                ripples.append(newRipple)
                
                // 清理旧涟漪
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    ripples.removeAll { $0.id == newRipple.id }
                }
            }
        }
    }
}

struct RippleModifier: ViewModifier {
    let startTime: Date
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 1
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    scale = 3
                    opacity = 0
                }
            }
    }
}

/// 渐变边框按钮
struct GradientBorderButton: View {
    let title: String
    let action: () -> Void
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: {
            action()
            HapticEngine.impact(.medium)
        }) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        // 动态渐变边框
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        .blue, .purple, .pink, .orange, .yellow, .green, .blue
                                    ],
                                    center: .center,
                                    angle: .degrees(rotation)
                                ),
                                lineWidth: 3
                            )
                            .blur(radius: 3)
                        
                        // 内容背景
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.black.opacity(0.8))
                    }
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

/// 呼吸灯按钮
struct BreathingButton: View {
    let systemName: String
    let action: () -> Void
    @State private var breathing = false
    
    var body: some View {
        Button(action: {
            action()
            HapticEngine.selection()
        }) {
            ZStack {
                // 呼吸光晕
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .scaleEffect(breathing ? 1.3 : 1.0)
                    .opacity(breathing ? 0.3 : 0.6)
                
                // 按钮主体
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: systemName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}