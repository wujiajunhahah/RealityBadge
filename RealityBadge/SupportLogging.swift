import Foundation
import os.log

enum RBLogger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.RealityBadge"
    static let general = OSLog(subsystem: subsystem, category: "general")
    static func log(_ msg: String) { os_log("%{public}@", log: general, type: .info, msg) }
    static func error(_ msg: String) { os_log("%{public}@", log: general, type: .error, msg) }
}

protocol RBErrorReporter {
    func capture(error: Error, context: [String: String]?)
}

struct RBNoopErrorReporter: RBErrorReporter {
    func capture(error: Error, context: [String : String]?) { /* no-op */ }
}

