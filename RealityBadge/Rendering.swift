import Foundation
import SwiftUI
import AVFoundation

// MARK: - Semantic Provider Protocol
protocol RBSemanticProvider {
    func process(sampleBuffer: CMSampleBuffer) -> SemanticScores
}

extension SemanticEngine: RBSemanticProvider {}

// MARK: - Badge Renderer Protocol
protocol RBBadgeRenderer {
    associatedtype V: View
    func makeView(badge: Badge, image: UIImage?, mask: UIImage?, depth: UIImage?) -> V
}

struct DefaultRBBadgeRenderer: RBBadgeRenderer {
    func makeView(badge: Badge, image: UIImage?, mask: UIImage?, depth: UIImage?) -> some View {
        Badge3DView(badge: badge, capturedImage: image, subjectMask: mask, depthMap: depth)
    }
}

enum RBRenderers {
    static var renderer: any RBBadgeRenderer = DefaultRBBadgeRenderer()
}
