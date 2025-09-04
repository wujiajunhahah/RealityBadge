import SwiftUI

enum BadgeStyle: String {
    case embossed, film, pixel
}

extension Badge {
    var styleEnum: BadgeStyle { BadgeStyle(rawValue: style) ?? .embossed }
}

struct BadgeStampView: View {
    let badge: Badge
    var body: some View {
        switch badge.styleEnum {
        case .embossed: EmbossedStamp(badge: badge)
        case .film:     FilmCard(badge: badge)
        case .pixel:    PixelBadge(badge: badge)
        }
    }
}

private struct EmbossedStamp: View {
    let badge: Badge
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 2))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
            Circle()
                .stroke(LinearGradient(colors: [.gray.opacity(0.2), .gray.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 10)
                .padding(10)
            VStack(spacing: 8) {
                if let p = badge.imagePath, let ui = UIImage(contentsOfFile: p) {
                    Image(uiImage: ui).resizable().scaledToFit().frame(width: 140, height: 140).clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Image(systemName: badge.symbol).font(.system(size: 56, weight: .semibold))
                }
                Text(badge.title).font(.system(.subheadline, design: .rounded).weight(.bold))
                Text(dateString(badge.date)).font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 220, height: 220)
    }
}

private struct FilmCard: View {
    let badge: Badge
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black)
                .overlay(
                    VStack(spacing: 0) {
                        perforation
                        ZStack {
                            Rectangle().fill(Color(.systemBackground))
                            VStack(spacing: 10) {
                                if let p = badge.imagePath, let ui = UIImage(contentsOfFile: p) {
                                    Image(uiImage: ui).resizable().scaledToFit().frame(height: 96).clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    Image(systemName: badge.symbol).font(.system(size: 56, weight: .semibold))
                                }
                                Text(badge.title).font(.system(.subheadline, design: .rounded).weight(.bold))
                                Text(dateString(badge.date)).font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        perforation
                    }
                )
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 8)
        }
        .frame(width: 260, height: 200)
    }
    private var perforation: some View {
        HStack(spacing: 6) {
            ForEach(0..<10, id: \.self) { _ in Circle().fill(Color(.systemBackground)).frame(width: 8, height: 8) }
        }
        .padding(8)
    }
}

private struct PixelBadge: View {
    let badge: Badge
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4,3]))
                        .foregroundStyle(.gray.opacity(0.3))
                )
            VStack(spacing: 8) {
                if let p = badge.imagePath, let ui = UIImage(contentsOfFile: p) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 96)
                        .overlay(gridOverlay)
                } else {
                    Image(systemName: badge.symbol)
                        .font(.system(size: 52, weight: .semibold))
                        .overlay(gridOverlay)
                }
                Text(badge.title).font(.system(.subheadline, design: .rounded).weight(.bold))
                Text(dateString(badge.date)).font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .frame(width: 220, height: 180)
    }
    private var gridOverlay: some View {
        GeometryReader { geo in
            Path { p in
                let s: CGFloat = 6
                let w = geo.size.width
                let h = geo.size.height
                var x: CGFloat = 0
                while x <= w { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h)); x += s }
                var y: CGFloat = 0
                while y <= h { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y)); y += s }
            }
            .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}
