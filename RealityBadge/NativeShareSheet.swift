import SwiftUI
import UIKit

// MARK: - 原生 ShareSheet 分享功能

struct ShareSheetHelper {
    static func share(items: [Any], from view: UIView? = nil) {
        guard let source = view?.window?.rootViewController else {
            // 如果没有 view，使用最顶层的 window
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                presentSheet(items: items, from: rootViewController)
                return
            }
            return
        }
        presentSheet(items: items, from: source)
    }

    private static func presentSheet(items: [Any], from viewController: UIViewController) {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // iPad 适配
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        viewController.present(activityViewController, animated: true)
    }
}

// MARK: - SwiftUI 分享按钮
struct NativeShareButton: View {
    let items: [Any]
    let title: String
    let icon: String

    init(
        title: String = "分享",
        icon: String = "square.and.arrow.up",
        items: [Any]
    ) {
        self.title = title
        self.icon = icon
        self.items = items
    }

    var body: some View {
        Button {
            ShareSheetHelper.share(items: items)
        } label: {
            Label(title, systemImage: icon)
                .font(.system(.body, weight: .medium))
        }
    }
}

// MARK: - SwiftUI ShareLink（iOS 16+）
@available(iOS 16.0, *)
struct NativeShareLink: View {
    let items: [Any]
    let subject: String?
    let message: String?

    init(
        items: [Any],
        subject: String? = nil,
        message: String? = nil
    ) {
        self.items = items
        self.subject = subject
        self.message = message
    }

    var body: some View {
        if let url = items.first as? URL {
            ShareLink(item: url, subject: subject, message: message) {
                Label("分享", systemImage: "square.and.arrow.up")
                    .font(.system(.body, weight: .medium))
            }
        } else if let image = items.first as? UIImage {
            ShareLink(item: image, subject: subject, message: message) {
                Label("分享", systemImage: "square.and.arrow.up")
                    .font(.system(.body, weight: .medium))
            }
        } else {
            EmptyView()
        }
    }
}

// MARK: - 使用示例
struct ShareExampleView: View {
    @State private var badgeImage: UIImage?
    @State private var badgeTitle = "我的徽章"

    var body: some View {
        VStack(spacing: 20) {
            Text("分享徽章")
                .font(.system(.headline))

            // 方法 1：使用 ShareButton
            if let image = badgeImage {
                NativeShareButton(
                    title: "分享徽章",
                    icon: "square.and.arrow.up",
                    items: [image, badgeTitle]
                )
            }

            // 方法 2：使用 ShareLink（iOS 16+）
            if #available(iOS 16.0, *), let image = badgeImage {
                NativeShareLink(
                    items: [image],
                    subject: badgeTitle,
                    message: "看看我的新徽章！"
                )
            }
        }
        .padding()
    }
}

// MARK: - 分享预览扩展
struct SharePreview: View {
    let badge: Badge
    let image: UIImage?

    init(badge: Badge, image: UIImage? = nil) {
        self.badge = badge
        self.image = image
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: badge.symbol)
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(badge.title)
                    .font(.system(.headline, weight: .semibold))

                Text(dateString(badge.date))
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 分享扩展：自定义分享表单
@available(iOS 16.0, *)
struct CustomShareSheet: View {
    let badge: Badge
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss

    init(badge: Badge, image: UIImage? = nil) {
        self.badge = badge
        self.image = image
    }

    var body: some View {
        NavigationStack {
            List {
                // 分享预览
                Section {
                    SharePreview(badge: badge, image: image)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 分享选项
                Section("分享到") {
                    ShareLink(item: buildShareText()) {
                        Label("信息", systemImage: "message")
                    }

                    ShareLink(item: buildShareText()) {
                        Label("邮件", systemImage: "envelope")
                    }

                    ShareLink(item: buildShareText()) {
                        Label("备忘录", systemImage: "note.text")
                    }

                    NativeShareButton(
                        title: "更多选项",
                        icon: "ellipsis",
                        items: buildShareItems()
                    )
                }
            }
            .navigationTitle("分享徽章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func buildShareText() -> String {
        "看看我的新徽章：\(badge.title)！#RealityBadge"
    }

    private func buildShareItems() -> [Any] {
        var items: [Any] = [buildShareText()]

        if let image = image {
            items.append(image)
        }

        if let imagePath = badge.imagePath,
           let imageData = try? Data(contentsOf: imageURL(fileSystemPath: imagePath)) {
            items.append(imageData)
        }

        return items
    }
}

#Preview {
    if let sampleImage = UIImage(systemName: "star.fill") {
        ShareExampleView(badgeImage: sampleImage)
    }
}
