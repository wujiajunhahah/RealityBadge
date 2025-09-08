import SwiftUI

struct BadgeWallView: View {
    @EnvironmentObject var state: AppState
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 14)]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("This Week 3/7")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(state.recentBadges) { b in
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                                    .frame(width: 96, height: 72)
                                if let imgPath = b.imagePath, let img = UIImage(contentsOfFile: imgPath) {
                                    if let mPath = b.maskPath, let m = UIImage(contentsOfFile: mPath), let cut = RBMakeSubjectCutout(image: img, mask: m) {
                                        Image(uiImage: cut)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 96, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } else {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 96, height: 72)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                } else {
                                    Image(systemName: b.symbol)
                                        .font(.system(size: 28, weight: .semibold))
                                }
                            }
                            Text(b.title).font(.system(.footnote, design: .rounded).weight(.semibold))
                            Text(dateString(b.date)).font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.15))
                                )
                        )
                        .onTapGesture {
                            HapticEngine.selection()
                            // 尝试从磁盘读取资源并进入结果页
                            let image = b.imagePath.flatMap { UIImage(contentsOfFile: $0) }
                            let mask = b.maskPath.flatMap { UIImage(contentsOfFile: $0) }
                            let depth = b.depthPath.flatMap { UIImage(contentsOfFile: $0) }
                            state.lastCapturedImage = image
                            state.lastSubjectMask = mask
                            state.lastDepthMap = depth
                            state.sheet = .badge3DPreview(b)
                        }
                    }
                    // 占位未完成
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(spacing: 8) {
                            Circle().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 2).frame(width: 72, height: 72)
                            Text("Soon").font(.system(.footnote, design: .rounded))
                            Text("--").font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.15)))
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Badge Library")
        .navigationBarTitleDisplayMode(.inline)
    }
}
