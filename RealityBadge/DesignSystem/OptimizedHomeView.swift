import SwiftUI

// MARK: - 优化后的主界面
// 基于苹果最新设计语言重构

struct OptimizedHomeView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab: AppleTabBar.Tab = .explore
    @State private var showCapture = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // 探索页面
            ExploreView()
                .tabItem {
                    Label("探索", systemImage: "safari.fill")
                }
                .tag(AppleTabBar.Tab.explore)

            // 徽章页面
            BadgesView()
                .tabItem {
                    Label("徽章", systemImage: "square.grid.2x2.fill")
                }
                .tag(AppleTabBar.Tab.badges)

            // 个人页面
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle.fill")
                }
                .tag(AppleTabBar.Tab.profile)
        }
        .tint(.systemBlue)
    }
}

// MARK: - 探索页面 (内容优先设计)
struct ExploreView: View {
    @EnvironmentObject var state: AppState
    @State private var showCapture = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 头部问候
                header
                    .padding(.top, 8)

                // 快速操作卡片
                quickActions

                // 推荐挑战
                recommendedChallenges

                // 最近徽章预览
                recentBadgesSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // 为底部 TabBar 留空间
        }
        .background(Color.systemBackground)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(.primaryLabel)

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
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12: return "早上好"
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
                showCapture = true
            }

            QuickActionCard(
                icon: "sparkles",
                title: "每日挑战",
                subtitle: "完成今日任务",
                color: .systemOrange
            ) {
                // TODO: 实现每日挑战
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
                // TODO: 实现导入
            }
        }
    }

    private var recommendedChallenges: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐挑战")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primaryLabel)

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

                    ChallengeCard(
                        icon: "umbrella.fill",
                        title: "雨中漫步",
                        description: "捕捉雨伞的瞬间",
                        difficulty: .easy
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
                    .foregroundStyle(.primaryLabel)

                Spacer()

                Button("查看全部") {
                    // TODO: 导航到全部徽章
                }
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(.systemBlue)
            }

            if state.recentBadges.isEmpty {
                emptyBadgesState
            } else {
                BadgeGrid(badges: Array(state.recentBadges.prefix(5))) { badge in
                    // TODO: 显示徽章详情
                }
            }
        }
    }

    private var emptyBadgesState: some View {
        AppleStyleCard(style: .flat) {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiaryLabel)

                Text("还没有徽章")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primaryLabel)

                Text("开始扫描，创建你的第一个徽章吧")
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondaryLabel)
                    .multilineTextAlignment(.center)

                AppleStyleButton("开始创建", style: .primary) {
                    showCapture = true
                }
            }
            .padding(24)
        }
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
                        .foregroundStyle(.primaryLabel)

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
    let difficulty: Difficulty

    enum Difficulty {
        case easy, medium, hard

        var color: Color {
            switch self {
            case .easy: return .systemGreen
            case .medium: return .systemOrange
            case .hard: return .systemRed
            }
        }

        var text: String {
            switch self {
            case .easy: return "简单"
            case .medium: return "中等"
            case .hard: return "困难"
            }
        }
    }

    var body: some View {
        AppleStyleCard(style: .elevated) {
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

                        Text(difficulty.text)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(difficulty.color)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.primaryLabel)

                    Text(description)
                        .font(.system(.caption))
                        .foregroundStyle(.secondaryLabel)
                }

                AppleStyleButton("接受挑战", style: .secondary) {
                    // TODO: 开始挑战
                }
            }
        }
        .frame(width: 200)
    }
}

// MARK: - 徽章页面
struct BadgesView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计卡片
                statsCard

                // 筛选器
                filterBar

                // 徽章网格
                badgesGrid
            }
            .padding(20)
        }
        .background(Color.systemBackground)
        .navigationTitle("我的徽章")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsCard: some View {
        HStack(spacing: 16) {
            StatItem(
                value: "\(state.recentBadges.count)",
                label: "总徽章",
                color: .systemBlue
            )

            Divider()
                .frame(height: 40)

            StatItem(
                value: "12",
                label: "本周新增",
                color: .systemGreen
            )

            Divider()
                .frame(height: 40)

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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部", isSelected: true)
                FilterChip(title: "本周", isSelected: false)
                FilterChip(title: "本月", isSelected: false)
                FilterChip(title: "收藏", isSelected: false)
            }
            .padding(.horizontal, 20)
        }
    }

    private var badgesGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 12)
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

// MARK: - 筛选芯片
struct FilterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(.subheadline, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .white : .primaryLabel)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.systemBlue : Color.tertiarySystemFill)
            .clipShape(Capsule())
    }
}

// MARK: - 个人页面
struct ProfileView: View {
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
                            .foregroundStyle(.primaryLabel)

                        Text("徽章收藏家")
                            .font(.system(.subheadline))
                            .foregroundStyle(.secondaryLabel)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.tertiaryLabel)
                }
                .padding(.vertical, 8)
            }

            // 设置选项
            Section("设置") {
                SettingRow(icon: "bell.badge", title: "通知", color: .systemRed)
                SettingRow(icon: "lock", title: "隐私", color: .systemBlue)
                SettingRow(icon: "paintbrush", title: "外观", color: .systemPurple)
                SettingRow(icon: "text.alignleft", title: "语言", color: .systemOrange)
            }

            // 支持
            Section("支持") {
                SettingRow(icon: "questionmark.circle", title: "帮助", color: .systemGreen)
                SettingRow(icon: "envelope", title: "联系我们", color: .systemBlue)
                SettingRow(icon: "star.fill", title: "评分", color: .systemYellow)
            }

            // 关于
            Section("关于") {
                SettingRow(icon: "info.circle", title: "版本", subtitle: "1.0.0", color: .gray)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 设置行
struct SettingRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color

    init(icon: String, title: String, subtitle: String? = nil, color: Color) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body))
                    .foregroundStyle(.primaryLabel)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(.secondaryLabel)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.tertiaryLabel)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览
#Preview {
    OptimizedHomeView()
        .environmentObject(AppState())
}
