import SwiftUI
import UIKit

// MARK: - 优化版 HomeView
// 使用苹果原生组件，移除过度设计

struct HomeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 头部问候
                    header
                        .padding(.top, 8)

                    // 主要操作
                    primaryAction

                    // 最近徽章
                    recentBadges
                }
                .padding(20)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("RealityBadge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        state.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(.largeTitle, weight: .bold))

                Text(currentDate)
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondary)
            }

            Spacer()
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

    private var primaryAction: some View {
        Button {
            state.showCapture = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 28, weight: .semibold))

                VStack(alignment: .leading, spacing: 4) {
                    Text("开始扫描")
                        .font(.system(.body, weight: .semibold))

                    Text("创建你的第一个徽章")
                        .font(.system(.caption))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(Color(UIColor.systemBlue))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
                        NativeBadgeCard(badge: badge)
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
        .padding(.top, 40)
    }
}

// MARK: - 原生徽章卡片
struct NativeBadgeCard: View {
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

#Preview {
    HomeView()
        .environmentObject(AppState())
}
