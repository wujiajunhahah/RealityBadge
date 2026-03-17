import SwiftUI

// MARK: - RealityBadge 应用入口（重构版）
// 使用苹果最新设计语言和原生组件

@main
struct RealityBadgeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .onAppear {
                    initializeApp()
                }
        }
    }

    private func initializeApp() {
        // 加载已保存的徽章
        let existing = RBRepository.badges.loadAll()
        if !existing.isEmpty {
            appState.recentBadges = existing
        }

        // 配置文档导入
        RBDocumentOpener.shared.handler = { url in
            RBBadgeImportHelper.importPackage(at: url, into: appState)
        }

        // 配置深度链接
        RBDeepLinkOpener.shared.handler = { url in
            RBRouter.handle(url: url, state: appState)
        }
    }
}

// MARK: - 主标签视图（底部导航）
struct MainTabView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab = Tab.explore

    enum Tab: String, CaseIterable {
        case explore = "探索"
        case badges = "徽章"
        case create = "拍摄"
        case profile = "我的"

        var icon: String {
            switch self {
            case .explore: return "safari.fill"
            case .badges: return "square.grid.2x2.fill"
            case .create: return "camera.fill"
            case .profile: return "person.crop.circle.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ExploreView()
                .tabItem {
                    Label(Tab.explore.rawValue, systemImage: Tab.explore.icon)
                }
                .tag(Tab.explore)

            BadgesView()
                .tabItem {
                    Label(Tab.badges.rawValue, systemImage: Tab.badges.icon)
                }
                .tag(Tab.badges)

            CaptureViewWrapper()
                .tabItem {
                    Label(Tab.create.rawValue, systemImage: Tab.create.icon)
                }
                .tag(Tab.create)

            ProfileView()
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(.systemBlue)
    }
}

// MARK: - 拍摄视图包装器
struct CaptureViewWrapper: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationView {
            AppleStyleCaptureView()
                .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - 探索视图（内容优先设计）
struct ExploreView: View {
    @EnvironmentObject var state: AppState
    @State private var showCapture = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 头部问候
                header
                    .padding(.top, 8)

                // 快速操作
                quickActions

                // 推荐挑战
                recommendedChallenges

                // 最近徽章
                recentBadgesSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.systemBackground)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(.title2, weight: .bold))

                Text(currentDate)
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondaryLabel)
            }

            Spacer()

            Button {
                state.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondaryLabel)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 6..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "3月17日 星期一"
        return formatter.string(from: .now)
    }

    private var quickActions: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 16) {
            QuickActionCard(
                icon: "camera.aperture",
                title: "开始扫描",
                subtitle: "创建新徽章",
                color: .systemBlue
            ) {
                // TODO: 触发扫描
            }

            QuickActionCard(
                icon: "sparkles",
                title: "每日挑战",
                subtitle: "完成今日任务",
                color: .systemOrange
            ) {
                // TODO: 显示每日挑战
            }

            QuickActionCard(
                icon: "square.grid.2x2",
                title: "徽章墙",
                subtitle: "查看所有徽章",
                color: .systemGreen
            ) {
                // TODO: 导航到徽章墙
            }

            QuickActionCard(
                icon: "doc.text",
                title: "导入徽章",
                subtitle: "从文件导入",
                color: .systemPurple
            ) {
                // TODO: 触发导入
            }
        }
    }

    private var recommendedChallenges: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐挑战")
                .font(.system(.headline, weight: .semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ChallengeCard(
                        icon: "tree.fill",
                        title: "触摸大自然",
                        description: "拍摄一棵树的徽章",
                        difficulty: .easy
                    )

                    ChallengeCard(
                        icon: "cup.and.saucer.fill",
                        title: "咖啡时光",
                        description: "记录你的咖啡杯",
                        difficulty: .medium
                    )
                }
            }
        }
    }

    private var recentBadgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近徽章")
                    .font(.system(.headline, weight: .semibold))

                Spacer()

                Button("查看全部") {
                    // TODO: 导航到全部徽章
                }
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.systemBlue)
            }

            if state.recentBadges.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 12)
                ], spacing: 12) {
                    ForEach(state.recentBadges.prefix(6)) { badge in
                        BadgeCard(badge: badge)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.tertiaryLabel)

            Text("还没有徽章")
                .font(.system(.headline, weight: .semibold))

            Text("开始扫描，创建你的第一个徽章吧")
                .font(.system(.subheadline))
                .foregroundStyle(.secondaryLabel)
                .multilineTextAlignment(.center)

            Button {
                // TODO: 触发扫描
            } label: {
                Text("开始创建")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.systemBlue)
                    .clipShape(Capsule())
            }
        }
        .padding(32)
    }
}

// MARK: - 快速操作卡片
struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.subheadline, weight: .semibold))

                    Text(subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(.secondaryLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 挑战卡片
struct ChallengeCard: View {
    let icon: String
    let title: String
    let description: String
    let difficulty: QuickActionCard

    enum Difficulty {
        case easy, medium, hard

        var color: Color {
            switch self {
            case .easy: return .systemGreen
            case .medium: return .systemOrange
            case .hard: return .systemRed
            }
        }
    }

    init(
        icon: String,
        title: String,
        description: String,
        difficulty: Difficulty
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.difficulty = difficulty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.systemBlue)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(difficulty.color)
                        .frame(width: 6, height: 6)

                    Text(difficulty.color == .systemGreen ? "简单" : difficulty.color == .systemOrange ? "中等" : "困难")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(difficulty.color)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))

                Text(description)
                    .font(.system(.caption))
                    .foregroundStyle(.secondaryLabel)
            }
        }
        .padding(16)
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(width: 200)
    }
}

// MARK: - 徽章视图（优化版）
struct BadgesView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedFilter = 0

    private let filters = ["全部", "本周", "收藏"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 统计信息
                statsCard

                // 筛选器
                filterPicker

                // 徽章网格
                badgesGrid
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background(Color.systemBackground)
        .navigationTitle("我的徽章")
        .navigationBarTitleDisplayMode(.large)
    }

    private var statsCard: some View {
        HStack(spacing: 24) {
            StatItem(
                value: "\(state.recentBadges.count)",
                label: "总徽章",
                color: .systemBlue
            )

            StatItem(
                value: "12",
                label: "本周新增",
                color: .systemGreen
            )

            StatItem(
                value: "85%",
                label: "完成率",
                color: .systemOrange
            )
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var filterPicker: some View {
        Picker("", selection: $selectedFilter) {
            ForEach(0..<filters.count, id: \.self) { index in
                Text(filters[index])
                    .tag(index)
            }
        }
        .pickerStyle(.segmented)
    }

    private var badgesGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 150), spacing: 12)
        ], spacing: 12) {
            ForEach(state.recentBadges) { badge in
                BadgeCard(badge: badge)
            }
        }
    }
}

// MARK: - 统计项
struct StatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(color)

            Text(label)
                .font(.system(.caption))
                .foregroundStyle(.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 个人视图
struct ProfileView: View {
    @State private var notificationsEnabled = true

    var body: some View {
        List {
            // 个人资料
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color.tertiarySystemFill)
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiaryLabel)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("JiaJun Wu")
                            .font(.system(.headline, weight: .semibold))

                        Text("徽章收藏家")
                            .font(.system(.subheadline))
                            .foregroundStyle(.secondaryLabel)
                    }
                }
                .padding(.vertical, 8)
            }

            // 设置
            Section("设置") {
                AppleStyleToggle("推送通知", isOn: $notificationsEnabled)

                HStack {
                    Label("隐私", systemImage: "lock")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.tertiaryLabel)
                }

                HStack {
                    Label("语言", systemImage: "text.alignleft")
                    Spacer()
                    Text("简体中文")
                        .foregroundStyle(.secondaryLabel)
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.tertiaryLabel)
                }
            }

            // 支持
            Section("支持") {
                HStack {
                    Label("帮助", systemImage: "questionmark.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.tertiaryLabel)
                }

                HStack {
                    Label("联系我们", systemImage: "envelope")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.tertiaryLabel)
                }

                HStack {
                    Label("评分", systemImage: "star")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.tertiaryLabel)
                }
            }

            // 关于
            Section("关于") {
                HStack {
                    Label("版本", systemImage: "info.circle")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondaryLabel)
                }
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - 苹果风格开关
struct AppleStyleToggle: View {
    @Binding var isOn: Bool
    let title: String

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: $isOn)
        }
    }
}

// MARK: - 扩展：UIColor 转换
extension Color {
    init(_ uiColor: UIColor) {
        self.init(uiColor.cgColor)
    }
}

// MARK: - 预览
#Preview {
    MainTabView()
        .environmentObject(AppState())
}
