import SwiftUI
import RealityKit
import ARKit

struct ARDeskPreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ARViewContainer(image: image)
                .ignoresSafeArea()
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

private struct ARViewContainer: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        config.environmentTexturing = .automatic
        view.session.run(config)

        // Tap to place
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.arView = view
        context.coordinator.image = image
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var arView: ARView?
        var image: UIImage?

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let arView = arView, let img = image else { return }
            let location = g.location(in: arView)
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            guard let first = results.first else { return }

            // Compute plane size preserving aspect ratio (~30cm height)
            let h: Float = 0.30
            let ratio = Float(img.size.width / max(img.size.height, 1))
            let w: Float = h * ratio

            let mesh = MeshResource.generatePlane(width: w, height: h)
            var material = UnlitMaterial()
            if let cg = img.cgImage {
                let texOpts = TextureResource.CreateOptions(semantic: .color)
                if let tex = try? TextureResource.generate(from: cg, options: texOpts) {
                    material.baseColor = .texture(tex)
                } else {
                    material.baseColor = .color(.white)
                }
            } else {
                material.baseColor = .color(.white)
            }
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.generateCollisionShapes(recursive: true)

            let anchor = AnchorEntity(world: first.worldTransform)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)

            // Gestures
            arView.installGestures([.translation, .rotation, .scale], for: entity)
        }
    }
}
