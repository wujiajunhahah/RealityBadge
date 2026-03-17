import SwiftUI

// MARK: - Apple Design System Components
// 基于苹果最新设计语言的 UI 组件库

// MARK: - 1. 系统颜色扩展 (使用语义化系统颜色)
extension Color {
    /// Apple 系统蓝色 - 用于主要操作
    static let systemBlue = Color(.systemBlue)
    /// Apple 系统绿色 - 用于成功状态
    static let systemGreen = Color(.systemGreen)
    /// Apple 系统橙色 - 用于警告
    static let systemOrange = Color(.systemOrange)
    /// Apple 系统红色 - 用于错误
    static let systemRed = Color(.systemRed)
    /// Apple 系统背景色
    static let systemBackground = Color(UIColor.systemBackground)
    /// Apple 次级背景色
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    /// Apple 第三级背景色
    static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)

    /// 语义化标签颜色
    static let primaryLabel = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)

    /// 分隔线颜色
    static let separator = Color(UIColor.separator)
    static let opaqueSeparator = Color(UIColor.opaqueSeparator)

    /// 填充颜色
    static let systemFill = Color(.systemFill)
    static let secondarySystemFill = Color(.secondarySystemFill)
    static let tertiarySystemFill = Color(.tertiarySystemFill)

    /// 自定义品牌色 (保持品牌识别度)
    static let brandPrimary = Color(red: 0.2, green: 0.78, blue: 0.35)  // #34C759
    static let brandSecondary = Color(red: 0.17, green: 0.75, blue: 0.89) // #2BC0E4
}

// MARK: - 2. 液态玻璃容器组件 (使用原生材质)
struct LiquidGlassContainer<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat

    init(
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }

    var body: some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: Color.black.opacity(0.1),
                radius: shadowRadius,
                x: 0,
                y: 2
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            }
    }
}

// MARK: - 3. 苹果风格按钮
struct AppleStyleButton: View {
    enum Style {
        case primary      // 主要按钮 - 填充蓝色
        case secondary    // 次要按钮 - 描边样式
        case tertiary     // 第三级按钮 - 无背景
        case destructive  // 危险操作 - 红色
        case brand        // 品牌色按钮
    }

    let title: LocalizedStringKey
    let style: Style
    let action: () -> Void
    let isDisabled: Bool

    init(
        _ title: LocalizedStringKey,
        style: Style = .primary,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.action = action
        self.isDisabled = isDisabled
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive, .brand:
            return .white
        case .secondary:
            return .systemBlue
        case .tertiary:
            return .systemBlue
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            Color.systemBlue
        case .secondary:
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.systemBlue, lineWidth: 1.5)
        case .tertiary:
            Color.clear
        case .destructive:
            Color.systemRed
        case .brand:
            LinearGradient(
                colors: [Color.brandPrimary, Color.brandSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - 4. 底部工具栏 (符合苹果设计趋势)
struct AppleBottomBar: View {
    let leadingItem: (() -> AnyView)?
    let centerItem: (() -> AnyView)?
    let trailingItem: (() -> AnyView)?

    init(
        @ViewBuilder leading: () -> some View,
        @ViewBuilder trailing: () -> some View
    ) {
        self.leadingItem = { AnyView(leading()) }
        self.centerItem = nil
        self.trailingItem = { AnyView(trailing()) }
    }

    init(
        @ViewBuilder center: () -> some View
    ) {
        self.leadingItem = nil
        self.centerItem = { AnyView(center()) }
        self.trailingItem = nil
    }

    var body: some View {
        HStack(spacing: 16) {
            if let leading = leadingItem {
                leading()
                Spacer()
            }

            if let center = centerItem {
                center()
            }

            if let trailing = trailingItem {
                Spacer()
                trailing()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay {
            Rectangle()
                .fill(Color.separator)
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - 5. 浮动操作按钮
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandPrimary, Color.brandSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(
                    color: Color.brandPrimary.opacity(0.4),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 6. 苹果风格卡片
struct AppleStyleCard<Content: View>: View {
    let content: Content
    let style: CardStyle

    enum CardStyle {
        case elevated
        case flat
        case glass
    }

    init(style: CardStyle = .elevated, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.style = style
    }

    var body: some View {
        content
            .padding(16)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .elevated:
            Color.secondarySystemBackground
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        case .flat:
            Color.tertiarySystemBackground
        case .glass:
            .ultraThinMaterial
        }
    }
}

// MARK: - 7. 分段控制 (原生组件增强)
struct AppleStyleSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(0..<options.count, id: \.self) { index in
                Text(options[index])
                    .tag(index)
            }
        }
        .pickerStyle(.segmented)
        .background(Color.tertiarySystemFill, in: RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: - 8. 状态指示器
struct StatusIndicator: View {
    enum Status {
        case success
        case warning
        case error
        case loading
        case info
    }

    let status: Status
    let text: String?

    init(_ status: Status, text: String? = nil) {
        self.status = status
        self.text = text
    }

    var body: some View {
        HStack(spacing: 8) {
            indicator
            if let text = text {
                Text(text)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var indicator: some View {
        switch status {
        case .loading:
            ProgressView()
                .scaleEffect(0.8)
        default:
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
    }

    private var statusColor: Color {
        switch status {
        case .success: return .systemGreen
        case .warning: return .systemOrange
        case .error: return .systemRed
        case .loading: return .systemBlue
        case .info: return .systemBlue
        }
    }
}

// MARK: - 9. 徽章网格 (LazyVGrid 原生组件)
struct BadgeGrid: View {
    let badges: [Badge]
    let onSelect: (Badge) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: [GridItem(.fixed(200))], spacing: 16) {
                ForEach(badges) { badge in
                    BadgeCard(badge: badge)
                        .onTapGesture {
                            onSelect(badge)
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 10. 底部抽屉 (原生 sheet 样式)
struct AppleBottomSheet: View {
    let isPresented: Binding<Bool>
    let title: String?
    @ViewBuilder let content: () -> any View

    var body: some View {
        if isPresented.wrappedValue {
            ZStack {
                // 背景遮罩
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isPresented.wrappedValue = false
                        }
                    }

                // 抽屉内容
                VStack(spacing: 0) {
                    // 抓手指示器
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.separator)
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // 标题
                    if let title = title {
                        Text(title)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(.primaryLabel)
                            .padding(.bottom, 16)
                    }

                    // 内容
                    content()
                        .padding(.bottom, 32)
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -10)
                .padding(.horizontal, 16)
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }
}

// MARK: - 11. 徽章卡片 (优化版)
struct BadgeCard: View {
    let badge: Badge

    var body: some View {
        AppleStyleCard(style: .flat) {
            VStack(spacing: 12) {
                // 图片/图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.tertiarySystemFill)
                        .frame(width: 90, height: 66)

                    if let imagePath = badge.imagePath,
                       let image = UIImage(contentsOfFile: imagePath) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: badge.symbol)
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiaryLabel)
                    }
                }

                // 标题和日期
                VStack(spacing: 4) {
                    Text(badge.title)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.primaryLabel)
                        .lineLimit(2)

                    Text(dateString(badge.date))
                        .font(.system(.caption))
                        .foregroundStyle(.secondaryLabel)
                }
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 12. 交互式开关
struct AppleStyleToggle: View {
    @Binding var isOn: Bool
    let title: String
    let description: String?

    init(
        _ title: String,
        description: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.description = description
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.body))
                    .foregroundStyle(.primaryLabel)

                if let description = description {
                    Text(description)
                        .font(.system(.caption))
                        .foregroundStyle(.secondaryLabel)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - 13. 导航标签栏 (原生 TabView 样式)
struct AppleTabBar: View {
    enum Tab: String, CaseIterable {
        case explore = "探索"
        case badges = "徽章"
        case profile = "我的"

        var icon: String {
            switch self {
            case .explore: return "safari"
            case .badges: return "square.grid.2x2"
            case .profile: return "person.crop.circle"
            }
        }
    }

    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selection == tab ? .semibold : .regular))
                            .foregroundStyle(selection == tab ? .systemBlue : .secondaryLabel)

                        Text(tab.rawValue)
                            .font(.system(.caption2, weight: selection == tab ? .semibold : .regular))
                            .foregroundStyle(selection == tab ? .systemBlue : .secondaryLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.regularMaterial)
        .overlay {
            Rectangle()
                .fill(Color.separator)
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
