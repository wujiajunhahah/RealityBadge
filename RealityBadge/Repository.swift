import Foundation

// MARK: - Repository Protocols
protocol RBBadgeRepositoryProtocol {
    func loadAll() -> [Badge]
    func save(_ badge: Badge)
    func delete(id: UUID)
}

// MARK: - Shared Repository Entry Point
enum RBRepository {
    static var badges: RBBadgeRepositoryProtocol = RBDiskBadgeRepository()
}

// MARK: - Disk JSON Repository (simple, metadata only)
final class RBDiskBadgeRepository: RBBadgeRepositoryProtocol {
    private let fm = FileManager.default
    private let indexURL: URL

    init() {
        let doc = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = doc.appendingPathComponent("Badges", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.indexURL = dir.appendingPathComponent("index.json")
    }

    func loadAll() -> [Badge] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        guard let records = try? JSONDecoder().decode([RBBadgeRecord].self, from: data) else { return [] }
        return records.compactMap { $0.toBadge() }
    }

    func save(_ badge: Badge) {
        var current = loadAll()
        if let idx = current.firstIndex(where: { $0.id == badge.id }) {
            current[idx] = badge
        } else {
            current.insert(badge, at: 0)
        }
        persist(current)
    }

    func delete(id: UUID) {
        let current = loadAll().filter { $0.id != id }
        persist(current)
    }

    private func persist(_ badges: [Badge]) {
        let records = badges.map(RBBadgeRecord.init(badge:))
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: indexURL)
        }
    }
}

// MARK: - Codable Record
private struct RBBadgeRecord: Codable {
    let schemaVersion: Int
    let id: String
    let title: String
    let dateISO8601: String
    let style: String
    let done: Bool
    let symbol: String
    let imagePath: String?
    let maskPath: String?
    let depthPath: String?

    init(badge: Badge) {
        self.schemaVersion = badge.schemaVersion
        self.id = badge.id.uuidString
        self.title = badge.title
        self.dateISO8601 = ISO8601DateFormatter().string(from: badge.date)
        self.style = badge.style
        self.done = badge.done
        self.symbol = badge.symbol
        self.imagePath = badge.imagePath
        self.maskPath = badge.maskPath
        self.depthPath = badge.depthPath
    }

    func toBadge() -> Badge? {
        let date = ISO8601DateFormatter().date(from: dateISO8601) ?? .now
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Badge(
            id: uuid,
            title: title,
            date: date,
            style: style,
            done: done,
            symbol: symbol,
            imagePath: imagePath,
            maskPath: maskPath,
            depthPath: depthPath,
            schemaVersion: schemaVersion
        )
    }
}

