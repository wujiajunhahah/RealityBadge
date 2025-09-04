import SwiftUI

struct DepthParallaxView: View {
    let image: UIImage
    let depth: CGImage
    var levels: Int = 4
    @StateObject private var motion = RBMotion.shared
    @State private var cachedLayers: [UIImage] = []
    @State private var zoom: CGFloat = 1.0
    @State private var drag: CGSize = .zero
    @State private var lastDrag: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                if cachedLayers.isEmpty {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
                } else {
                    ForEach((0..<cachedLayers.count), id: \.self) { idx in
                        let layer = cachedLayers[idx]
                        let weight = CGFloat(idx+1) / CGFloat(cachedLayers.count) // 远层小，近层大
                        Image(uiImage: layer)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .clipped()
                            .scaleEffect(zoom)
                            .offset(x: (motion.roll * 18).toCGFloat() * weight + drag.width * weight,
                                    y: (motion.pitch * 18).toCGFloat() * weight + drag.height * weight)
                    }
                }
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                    .rotation3DEffect(.degrees(Double(motion.pitch * 22)), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(Double(-motion.roll * 22)), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            }
            .gesture(gestures)
            .onAppear { motion.start(); prepareLayers() }
            .onDisappear { motion.stop() }
        }
    }

    private var gestures: some Gesture {
        SimultaneousGesture(
            DragGesture().onChanged { v in drag = CGSize(width: lastDrag.width + v.translation.width, height: lastDrag.height + v.translation.height) }
                .onEnded { _ in lastDrag = drag },
            MagnificationGesture().onChanged { m in zoom = min(2.5, max(1.0, m)) }
        )
        .simultaneously(with: TapGesture(count: 2).onEnded { withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { zoom = (zoom > 1.1) ? 1.0 : 2.0 } })
    }

    private func prepareLayers() {
        DispatchQueue.global(qos: .userInitiated).async {
            let arr = DepthProcessor.layeredImages(image: image, depth: depth, levels: levels)
            DispatchQueue.main.async { self.cachedLayers = arr }
        }
    }
}

private extension Double { func toCGFloat() -> CGFloat { CGFloat(self) } }

