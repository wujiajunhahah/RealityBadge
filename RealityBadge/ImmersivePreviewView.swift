import SwiftUI

struct ImmersivePreviewView: View {
    let image: UIImage
    let mask: CGImage?
    let depth: CGImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if let d = depth {
                    DepthParallaxView(image: image, depth: d)
                } else {
                    ParallaxPreviewView(image: image, mask: mask, interactive: true)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.001))
                    .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 18)
            )
            .padding(.horizontal, 12)
            VStack { HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
            }.padding().padding(.top, 8); Spacer() }
        }
    }
}
