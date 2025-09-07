import SwiftUI

// MARK: - 自定义动画修饰符
struct PulseEffect: ViewModifier {
    @State private var scale: CGFloat = 1.0
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    scale = 1.1
                }
            }
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var shimmerOffset: CGFloat = -100
    let width: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 100)
                .offset(x: shimmerOffset)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    shimmerOffset = width + 100
                }
            }
    }
}

struct ParallaxMotion: ViewModifier {
    @ObservedObject var motion = RBMotion.shared
    let intensity: CGFloat
    
    func body(content: Content) -> some View {
        content
            .offset(
                x: motion.roll * intensity,
                y: motion.pitch * intensity
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: motion.roll)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: motion.pitch)
    }
}

struct FloatingEffect: ViewModifier {
    @State private var offset: CGFloat = 0
    let amplitude: CGFloat
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    offset = amplitude
                }
            }
    }
}

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var opacity: Double = 0.5
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    opacity = 0.9
                }
            }
    }
}

// MARK: - 扩展
extension View {
    func pulse(duration: Double = 1.5) -> some View {
        modifier(PulseEffect(duration: duration))
    }
    
    func shimmer(width: CGFloat = 300) -> some View {
        modifier(ShimmerEffect(width: width))
    }
    
    func parallaxMotion(intensity: CGFloat = 10) -> some View {
        modifier(ParallaxMotion(intensity: intensity))
    }
    
    func floating(amplitude: CGFloat = 10) -> some View {
        modifier(FloatingEffect(amplitude: amplitude))
    }
    
    func glow(color: Color = .white, radius: CGFloat = 10) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
}

// MARK: - 自定义过渡
struct ScaleAndFade: ViewModifier {
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
    }
}

struct SlideAndFade: ViewModifier {
    let isVisible: Bool
    let offset: CGFloat
    
    func body(content: Content) -> some View {
        content
            .offset(y: isVisible ? 0 : offset)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isVisible)
    }
}

// MARK: - 高级动画组件
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    let colors: [Color]
    
    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

struct ParticleEmitter: View {
    let particleCount: Int
    let colors: [Color]
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var scale: CGFloat
        var opacity: Double
        var color: Color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 6, height: 6)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .position(particle.position)
            }
            .onAppear {
                generateParticles(in: geometry.size)
                animateParticles()
            }
        }
    }
    
    private func generateParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: Double.random(in: 0.3...0.7),
                color: colors.randomElement() ?? .white
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            particles = particles.map { particle in
                var p = particle
                p.position.y -= 300
                return p
            }
        }
    }
}

// MARK: - 3D卡片翻转效果
struct FlipEffect: GeometryEffect {
    var angle: Double
    let axis: (x: CGFloat, y: CGFloat, z: CGFloat)
    
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let a = CGFloat(Angle(degrees: angle).radians)
        
        var transform3d = CATransform3DIdentity
        transform3d.m34 = -1/max(size.width, size.height)
        
        transform3d = CATransform3DRotate(transform3d, a, axis.x, axis.y, axis.z)
        transform3d = CATransform3DTranslate(transform3d, -size.width/2.0, -size.height/2.0, 0)
        
        let affineTransform = ProjectionTransform(CGAffineTransform(translationX: size.width/2.0, y: size.height/2.0))
        
        return ProjectionTransform(transform3d).concatenating(affineTransform)
    }
}

extension View {
    func flip3D(_ angle: Double, axis: (x: CGFloat, y: CGFloat, z: CGFloat)) -> some View {
        modifier(FlipEffect(angle: angle, axis: axis))
    }
}