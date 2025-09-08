import Foundation

protocol RBSchemaMigrator {
    var fromVersion: Int { get }
    var toVersion: Int { get }
    func canMigrate(_ badge: Badge) -> Bool
    func migrate(_ badge: Badge) -> Badge
}

enum RBMigrationRegistry {
    // 注册你的迁移器，按版本顺序
    static var migrators: [RBSchemaMigrator] = []

    static func migrateIfNeeded(_ badge: Badge) -> Badge {
        var current = badge
        for m in migrators where m.canMigrate(current) {
            current = m.migrate(current)
        }
        return current
    }
}

