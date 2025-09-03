import SwiftUI

struct CaptureView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var glow = false
    @State private var progress: CGFloat = 0
    @State private var isCapturing = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // 占位取景背景（后续替换为相机画面）
            LinearGradient(colors: [.black, .gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                Text(isCapturing ? "捕捉中…" : "语义快门已就绪")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 12)

                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 6)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                        .shadow(color: .white.opacity(glow ? 0.8 : 0.0), radius: glow ? 12 : 0)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever()) { glow.toggle() }
                    startSemanticSweep()
                }
                .padding(.bottom, 30)
            }
        }
    }

    private func startSemanticSweep() {
        timer?.invalidate()
        progress = 0
        isCapturing = false
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
            // 模拟语义相似度稳定上升
            let delta = CGFloat(Double.random(in: 0.03...0.08))
            progress = min(1.0, progress + delta)
            if progress >= 1.0 { t.invalidate(); capture() }
        }
    }

    private func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        RBHaptics.success()
        // 生成一枚临时徽章并弹出预览
        let new = Badge(title: "摸一棵大树", date: .now, style: state.settings.style, done: true, symbol: "tree")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            state.sheet = .badgePreview(new)
        }
    }
}