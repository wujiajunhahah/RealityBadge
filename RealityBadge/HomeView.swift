import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @Namespace private var ns
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header
                badgesPreview
                modeDial
                startButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
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
                Text("现实勋章")
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
                Text("徽章库")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Spacer()
                NavigationLink {
                    BadgeWallView()
                } label: {
                    Label("查看全部徽章", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(state.recentBadges) { b in
                        BadgeCard(badge: b)
                            .onTapGesture { state.sheet = .badgePreview(b) }
                    }
                }
                .padding(.vertical, 6)
            }
        }
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
            .onChange(of: state.mode) { _ in RBHaptics.light() }
            
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
            RBHaptics.medium()
            switch state.mode {
            case .discover:
                state.showCapture = true
            case .daily:
                state.sheet = .importChallenge(title: "今日挑战：摸一棵大树", hint: "镜头遇见树与手，它会自己知道")
            case .trends:
                state.sheet = .importChallenge(title: "热点：中秋·月亮", hint: "今晚，看一眼天空")
            case .saved:
                state.sheet = .importChallenge(title: "我的收藏：雨伞", hint: "雨天的小仪式")
            }
        } label: {
            Text("开始")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RBColors.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: RBColors.green.opacity(0.25), radius: 12, x: 0, y: 6)
        }
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
                Circle().fill(.ultraThinMaterial)
                    .frame(width: 72, height: 72)
                Image(systemName: badge.symbol)
                    .font(.system(size: 28, weight: .semibold))
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