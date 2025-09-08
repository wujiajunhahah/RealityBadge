import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @Namespace private var ns
    @State private var headerScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Lighter, youthful animated background
                AnimatedGradientBackground(colors: [
                    Color(hex: "#EAF7FF"),
                    Color(hex: "#EAFBF4"),
                    Color(hex: "#F3EBFF")
                ])
                
                VStack(spacing: 20) {
                    header
                        .scaleEffect(headerScale)
                    badgesPreview
                    modeDial
                    startButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .sheet(isPresented: $state.showSettings) { SettingsView() }
            .sheet(item: $state.sheet) { route in
                switch route {
                case .importChallenge(let title, let hint):
                    ChallengeSheet(title: title, hint: hint) {
                        state.showCapture = true
                    }
                    .presentationDetents([.fraction(0.38), .medium])
                case .badgePreview(let badge):
                    BadgePreviewSheet(badge: badge)
                        .presentationDetents([.medium, .large])
                case .badge3DPreview(let badge):
                    BadgeResultSheet(
                        badge: badge,
                        capturedImage: state.lastCapturedImage,
                        subjectMask: state.lastSubjectMask,
                        depthMap: state.lastDepthMap
                    )
                    .presentationDetents([.medium, .large])
                    .interactiveDismissDisabled(false)
                }
            }
            .navigationDestination(isPresented: $state.showCapture) {
                CaptureView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    private var header: some View {
        HStack {
            Button { state.showSettings = true } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 28, weight: .semibold))
            }
            Spacer()
            VStack(spacing: 4) {
                Text(RBStrings.t(.appTitle))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text(dateString(.now))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "questionmark.circle").opacity(0.001)
        }
    }
    
    private var badgesPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(RBStrings.t(.badgeLibrary))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(.black.opacity(0.9))
                Spacer()
                NavigationLink {
                    BadgeWallView()
                } label: {
                    Label(RBStrings.t(.viewAll), systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.black.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(state.recentBadges) { b in
                        BadgeCard(badge: b)
                            .onTapGesture {
                                HapticEngine.selection()
                                // 若该徽章已保存资源，则预加载到全局状态供预览使用
                                if let path = b.imagePath, let img = UIImage(contentsOfFile: path) {
                                    state.lastCapturedImage = img
                                } else {
                                    state.lastCapturedImage = nil
                                }
                                if let m = b.maskPath { state.lastSubjectMask = UIImage(contentsOfFile: m) } else { state.lastSubjectMask = nil }
                                if let d = b.depthPath { state.lastDepthMap = UIImage(contentsOfFile: d) } else { state.lastDepthMap = nil }
                                // 进入包含 3D/AR/沉浸 的高级预览
                                state.sheet = .badge3DPreview(b)
                            }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var modeDial: some View {
        VStack(spacing: 12) {
            TabView(selection: $state.mode) {
                ForEach(RBMode.allCases) { m in
                    VStack(spacing: 8) {
                        Image(systemName: m.symbol)
                            .font(.system(size: 36, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(state.mode == m ? RBColors.green : .secondary)
                            .padding(.bottom, 6)
                        Text(m.rawValue)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                        Text(m.subtitle)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 240)
                    }
                    .tag(m)
                    .padding()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .onChange(of: state.mode) { _, _ in 
                HapticEngine.selection()
            }
            
            HStack(spacing: 6) {
                ForEach(RBMode.allCases) { m in
                    Circle()
                        .fill(state.mode == m ? RBColors.green : Color.secondary.opacity(0.2))
                        .frame(width: state.mode == m ? 10 : 6, height: state.mode == m ? 10 : 6)
                        .animation(.easeInOut(duration: 0.2), value: state.mode)
                }
            }
        }
    }
    
    private var startButton: some View {
        Button {
            HapticEngine.shared.captureSuccess()
            switch state.mode {
            case .discover:
                state.showCapture = true
            case .daily:
                state.sheet = .importChallenge(title: "Daily Challenge: Touch a Tree", hint: "Point the camera at your hand and a tree")
            case .trends:
                state.sheet = .importChallenge(title: "Trend: Mid‑Autumn • Moon", hint: "Tonight, look up and capture the moon")
            case .saved:
                state.sheet = .importChallenge(title: "Saved Prompt: Umbrella", hint: "A small rainy‑day ritual")
            }
        } label: {
            ZStack {
                // Vibrant pill button
                if #available(iOS 17.0, *) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#34C759"), Color(hex: "#2BC0E4")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            LiquidGlassView(opacity: 0.25, blur: 10)
                                .clipShape(Capsule())
                        )
                } else {
                    Capsule().fill(Color(hex: "#2BC0E4"))
                }

                HStack(spacing: 8) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                    Text(RBStrings.t(.startExploring))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                }
                .foregroundStyle(.white)
            }
            .frame(height: 56)
            .shadow(color: Color(hex: "#2BC0E4").opacity(0.25), radius: 20, x: 0, y: 10)
            .shadow(color: Color(hex: "#34C759").opacity(0.2), radius: 40, x: 0, y: 20)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

func dateString(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy · MM · dd"
    return f.string(from: date)
}

struct BadgeCard: View {
    let badge: Badge
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                    .frame(width: 90, height: 66)
                if let p = badge.imagePath, let img = UIImage(contentsOfFile: p) {
                    if let mp = badge.maskPath, let m = UIImage(contentsOfFile: mp), let cut = RBMakeSubjectCutout(image: img, mask: m) {
                        Image(uiImage: cut)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 66)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    Image(systemName: badge.symbol)
                        .font(.system(size: 28, weight: .semibold))
                }
            }
            Text(badge.title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
            Text(dateString(badge.date))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}
