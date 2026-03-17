import SwiftUI

// MARK: - RealityBadge 简化版应用入口
// 移除过度设计，使用苹果原生组件

@main
struct RealityBadgeAppSimple: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - 主内容视图
struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "首页"
        case badges = "徽章"
        case profile = "我的"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .badges: return "square.grid.2x2.fill"
            case .profile: return "person.crop.circle.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            BadgesView()
                .tabItem {
                    Label(Tab.badges.rawValue, systemImage: Tab.badges.icon)
                }
                .tag(Tab.badges)

            ProfileView()
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(.systemBlue)
    }
}

// MARK: - 首页视图（简化版）
struct HomeView: View {
    @EnvironmentObject var state: AppState
    @State private var showCapture = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 头部问候
                    header
                        .padding(.top, 8)

                    // 快速操作
                    quickActions

                    // 最近徽章
                    recentBadges
                }
                .padding(20)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("RealityBadge")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("你好！")
                    .font(.system(.title2, weight: .bold))

                Text("开始创建你的第一个徽章")
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                state.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickActions: some View {
        VStack(spacing: 16) {
            // 主要操作：开始扫描
            Button {
                showCapture = true
            } label: {
                HStack {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 24, weight: .semibold))

                    Text("开始扫描")
                        .font(.system(.body, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
                .background(Color(UIColor.systemBlue))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            // 次要操作
            HStack(spacing: 12) {
                SecondaryAction(
                    icon: "square.grid.2x2",
                    title: "徽章墙"
                ) {
                    // TODO: 导航到徽章墙
                }

                SecondaryAction(
                    icon: "doc.text",
                    title: "导入"
                ) {
                    // TODO: 触发导入
                }
            }
        }
    }

    private var recentBadges: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近徽章")
                .font(.system(.headline, weight: .semibold))

            if state.recentBadges.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 12)
                ], spacing: 12) {
                    ForEach(state.recentBadges.prefix(6)) { badge in
                        SimpleBadgeCard(badge: badge)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("还没有徽章")
                .font(.system(.headline, weight: .semibold))

            Text("点击上方按钮开始创建")
                .font(.system(.subheadline))
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}

// MARK: - 次要操作卡片
struct SecondaryAction: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.systemBlue)

                Text(title)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 简单徽章卡片
struct SimpleBadgeCard: View {
    let badge: Badge

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 图标/图片
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(height: 100)

                if let imagePath = badge.imagePath,
                   let image = UIImage(contentsOfFile: imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: badge.symbol)
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                }
            }

            // 标题和日期
            VStack(alignment: .leading, spacing: 4) {
                Text(badge.title)
                    .font(.system(.subheadline, weight: .medium))
                    .lineLimit(1)

                Text(dateString(badge.date))
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 徽章视图（简化版）
struct BadgesView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计
                HStack {
                    StatItem(value: "\(state.recentBadges.count)", label: "总徽章")
                    StatItem(value: "0", label: "本周新增")
                    StatItem(value: "0%", label: "完成率")
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 徽章网格
                if state.recentBadges.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150), spacing: 12)
                    ], spacing: 12) {
                        ForEach(state.recentBadges) { badge in
                            SimpleBadgeCard(badge: badge)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("我的徽章")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("还没有徽章")
                .font(.system(.headline, weight: .semibold))
        }
        .padding(.top, 60)
    }
}

// MARK: - 统计项
struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(.systemBlue)

            Text(label)
                .font(.system(.caption))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 个人视图（简化版）
struct ProfileView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("JiaJun Wu")
                            .font(.system(.headline, weight: .semibold))

                        Text("徽章收藏家")
                            .font(.system(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("设置") {
                SettingRow(icon: "bell.badge", title: "通知")
                SettingRow(icon: "lock", title: "隐私")
                SettingRow(icon: "paintbrush", title: "外观")
                SettingRow(icon: "text.alignleft", title: "语言")
            }

            Section("支持") {
                SettingRow(icon: "questionmark.circle", title: "帮助")
                SettingRow(icon: "envelope", title: "联系我们")
                SettingRow(icon: "star.fill", title: "评分")
            }

            Section("关于") {
                SettingRow(icon: "info.circle", title: "版本", subtitle: "1.0.0")
            }
        }
        .navigationTitle("我的")
    }
}

// MARK: - 设置行
struct SettingRow: View {
    let icon: String
    let title: String
    let subtitle: String?

    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览
#Preview {
    ContentView()
        .environmentObject(AppState())
}
