import SwiftUI

struct BadgeWallView: View {
    @EnvironmentObject var state: AppState
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 14)]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("本周进度 3/7")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(state.recentBadges) { b in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle().fill(.ultraThinMaterial).frame(width: 72, height: 72)
                                Image(systemName: b.symbol).font(.system(size: 28, weight: .semibold))
                            }
                            Text(b.title).font(.system(.footnote, design: .rounded).weight(.semibold))
                            Text(dateString(b.date)).font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                    }
                    // 占位未完成
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(spacing: 8) {
                            Circle().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 2).frame(width: 72, height: 72)
                            Text("待收集").font(.system(.footnote, design: .rounded))
                            Text("--").font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.15)))
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("徽章库")
        .navigationBarTitleDisplayMode(.inline)
    }
}