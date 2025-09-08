import Foundation
import UserNotifications

// MARK: - HTTP Backend 示例（极简）
struct RBHTTPBackendService: RBBackendService {
    let baseURL: URL
    let session: URLSession = .shared

    func fetchRemoteConfig(completion: @escaping (FeatureFlags) -> Void) {
        let url = baseURL.appendingPathComponent("flags.json")
        let task = session.dataTask(with: url) { data, _, _ in
            guard let data = data, let flags = try? JSONDecoder().decode(FeatureFlags.self, from: data) else {
                completion(.default)
                return
            }
            completion(flags)
        }
        task.resume()
    }

    func uploadBadge(_ badge: Badge, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("upload")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let payload: [String: Any] = [
            "id": badge.id.uuidString,
            "title": badge.title,
            "date": ISO8601DateFormatter().string(from: badge.date),
            "style": badge.style,
            "symbol": badge.symbol,
            "schema": badge.schemaVersion
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = session.dataTask(with: req) { _, _, err in
            if let err = err { completion(.failure(err)) } else { completion(.success(())) }
        }
        task.resume()
    }
}

// MARK: - 本地通知占位
final class RBUserNotificationsService: NSObject, RBPushService, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
        center.delegate = self
    }

    func scheduleDailyChallenge(time: Date, frequencyPerWeek: Int) {
        // 简化：若频率为0则取消
        guard frequencyPerWeek > 0 else { cancelAll(); return }
        let content = UNMutableNotificationContent()
        content.title = "今日挑战"
        content.body = "看看今天能解锁哪枚现实徽章？"
        content.sound = .default

        var date = Calendar.current.dateComponents([.hour, .minute], from: time)
        date.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let req = UNNotificationRequest(identifier: "rb.daily.challenge", content: content, trigger: trigger)
        center.add(req, withCompletionHandler: nil)
    }

    func cancelAll() { center.removeAllPendingNotificationRequests() }
}

