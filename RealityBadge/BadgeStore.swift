import Foundation

enum BadgeStore {
    private static var fileURL: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RealityBadge", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("badges.json")
    }

    static func load() -> [Badge]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([Badge].self, from: data)
    }

    static func loadOrSamples() -> [Badge] {
        if let arr = load() { return arr }
        return [
            .init(title: "大树", date: .now, style: "embossed", done: true, symbol: "tree"),
            .init(title: "咖啡杯", date: .now.addingTimeInterval(-86400.0*3), style: "film", done: true, symbol: "cup.and.saucer"),
            .init(title: "雨伞", date: .now.addingTimeInterval(-86400.0*10), style: "pixel", done: false, symbol: "umbrella")
        ]
    }

    static func save(_ badges: [Badge]) {
        if let data = try? JSONEncoder().encode(badges) {
            try? data.write(to: fileURL)
        }
    }
}

