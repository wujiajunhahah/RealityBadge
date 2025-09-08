import Foundation

// 预留：后台任务调度（未启用）。
enum RBBackgroundTasks {
    static func register() {
        // 将来使用 BGTaskScheduler.register(forTaskWithIdentifier:...) 在此注册
    }
    static func scheduleRefresh() {
        // 将来调度拉取 flags/挑战等
    }
}

