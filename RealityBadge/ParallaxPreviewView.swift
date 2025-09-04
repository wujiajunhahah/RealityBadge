import SwiftUI

struct ParallaxPreviewView: View {
    let image: UIImage
    let mask: CGImage?
    var interactive: Bool = true
    @StateObject private var motion = RBMotion.shared
    @State private var zoom: CGFloat = 1.0
    @State private var drag: CGSize = .zero
    @State private var lastDrag: CGSize = .zero
    @State private var cachedBG: UIImage?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // 背景使用模糊（若有掩膜则按掩膜衰减）
                Group {
                    if let bg = cachedBG ?? blurredBackground(image: image, mask: mask) {
                        Image(uiImage: bg).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
                    } else {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
                    }
                }
                // 卡片主体（不黑化原图）
                Group {
                    if let masked = cutForeground(image: image, mask: mask) {
                        Image(uiImage: masked)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .clipped()
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .clipped()
                    }
                }
                .scaleEffect(zoom)
                .rotation3DEffect(.degrees(Double(motion.pitch * 22)), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .rotation3DEffect(.degrees(Double(-motion.roll * 22)), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .offset(x: drag.width * 0.9, y: drag.height * 0.9)
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
                .animation(.easeOut(duration: 0.15), value: motion.pitch)

                // 边框（围起来 + 旋转一致）
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                    .rotation3DEffect(.degrees(Double(motion.pitch * 22)), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(Double(-motion.roll * 22)), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            }
            .contentShape(Rectangle())
            .gesture(interactive ? gestures : nil)
            .onAppear { motion.start(); prepareBG() }
            .onDisappear { motion.stop() }
            .onChange(of: mask) { _ , _ in prepareBG() }
            .onChange(of: image) { _ , _ in prepareBG() }
        }
    }

    private var gestures: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { v in
                    drag = CGSize(width: lastDrag.width + v.translation.width, height: lastDrag.height + v.translation.height)
                }
                .onEnded { _ in lastDrag = drag },
            MagnificationGesture()
                .onChanged { m in
                    zoom = min(2.6, max(1.0, m))
                }
        )
        .simultaneously(with: TapGesture(count: 2).onEnded { withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { zoom = (zoom > 1.1) ? 1.0 : 2.0 } })
    }

    private func cutForeground(image: UIImage, mask: CGImage?) -> UIImage? {
        guard let mask else { return nil }
        guard let cg = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cg)
        let ciMask = CIImage(cgImage: mask)
        let context = CIContext()

        guard let filter = CIFilter(name: "CIBlendWithMask") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIImage(color: .clear).cropped(to: ciImage.extent), forKey: kCIInputBackgroundImageKey)
        filter.setValue(ciMask, forKey: kCIInputMaskImageKey)
        guard let out = filter.outputImage, let cgOut = context.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cgOut)
    }

    private func blurredBackground(image: UIImage, mask: CGImage?) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        let context = CIContext()
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = ci
        blur.radius = 12
        let blurred = blur.outputImage?.cropped(to: ci.extent)
        guard let blurredCI = blurred else { return nil }
        if let mask = mask {
            // 反相掩膜：背景区域 = 1，前景 = 0
            let ciMask = CIImage(cgImage: mask)
            guard let invert = CIFilter(name: "CIColorInvert") else { return UIImage(cgImage: cg) }
            invert.setValue(ciMask, forKey: kCIInputImageKey)
            let inv = invert.outputImage ?? ciMask
            guard let blend = CIFilter(name: "CIBlendWithMask") else { return UIImage(cgImage: cg) }
            blend.setValue(blurredCI, forKey: kCIInputImageKey)
            blend.setValue(ci, forKey: kCIInputBackgroundImageKey)
            blend.setValue(inv, forKey: kCIInputMaskImageKey)
            if let out = blend.outputImage, let cgOut = context.createCGImage(out, from: out.extent) {
                return UIImage(cgImage: cgOut)
            }
        }
        if let cgOut = context.createCGImage(blurredCI, from: blurredCI.extent) { return UIImage(cgImage: cgOut) }
        return UIImage(cgImage: cg)
    }

    private func prepareBG() {
        let img = image; let m = mask
        DispatchQueue.global(qos: .userInitiated).async {
            let bg = blurredBackground(image: img, mask: m)
            DispatchQueue.main.async { self.cachedBG = bg }
        }
    }
}
