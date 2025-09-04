import Foundation
import UserNotifications
import SwiftUI

enum NotificationManager {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func registerCategories() {
        let openAction = UNNotificationAction(identifier: "rb.capture", title: "打开相机", options: [.foreground])
        let category = UNNotificationCategory(identifier: "CHALLENGE", actions: [openAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func scheduleDailyChallenge(at hour: Int) {
        var dc = DateComponents()
        dc.hour = hour
        let content = UNMutableNotificationContent()
        content.title = "今天的现实小任务"
        content.body = "去摸一棵大树，拿下你的浮雕勋章。"
        content.categoryIdentifier = "CHALLENGE"

        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let req = UNNotificationRequest(identifier: "daily.challenge", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    static func scheduleDebug(after seconds: TimeInterval = 10) {
        let content = UNMutableNotificationContent()
        content.title = "调试推送"
        content.body = "10 秒定时到，点我打开相机"
        content.categoryIdentifier = "CHALLENGE"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let req = UNNotificationRequest(identifier: "debug.challenge.\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    static func clearScheduled() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "daily.challenge",
            "mwf.challenge.mon",
            "mwf.challenge.wed",
            "mwf.challenge.fri"
        ])
    }

    static func reschedule(pushDate: Date, freq: Int) {
        clearScheduled()
        guard freq > 0 else { return }
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: pushDate)
        let hour = comps.hour ?? 9
        let minute = comps.minute ?? 0
        if freq == 1 {
            var dc = DateComponents()
            dc.hour = hour
            dc.minute = minute
            let content = UNMutableNotificationContent()
            content.title = "今天的现实小任务"
            content.body = "去摸一棵大树，拿下你的浮雕勋章。"
            content.categoryIdentifier = "CHALLENGE"
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let req = UNNotificationRequest(identifier: "daily.challenge", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(req)
        } else {
            // 每周三次：周一/三/五
            for (wd, id) in [(2, "mwf.challenge.mon"), (4, "mwf.challenge.wed"), (6, "mwf.challenge.fri")] {
                var dc = DateComponents()
                dc.weekday = wd
                dc.hour = hour
                dc.minute = minute
                let content = UNMutableNotificationContent()
                content.title = "本周现实小任务"
                content.body = "今天也来一个小挑战"
                content.categoryIdentifier = "CHALLENGE"
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(req)
            }
        }
    }

    static func rescheduleFromDefaults() {
        let d = UserDefaults.standard
        let t = d.double(forKey: "rb.push.time")
        let f = d.integer(forKey: "rb.push.freq")
        let date = (t > 0) ? Date(timeIntervalSince1970: t) : Date()
        reschedule(pushDate: date, freq: f)
    }
}

final class RBAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.requestAuthorization()
        NotificationManager.registerCategories()
        // 根据用户设置（@AppStorage）安排推送
        NotificationManager.rescheduleFromDefaults()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.actionIdentifier == "rb.capture" || response.notification.request.content.categoryIdentifier == "CHALLENGE" {
            NotificationCenter.default.post(name: .rbOpenCapture, object: nil)
        }
    }
}

extension Notification.Name {
    static let rbOpenCapture = Notification.Name("rb.open.capture")
    static let rbCaptureResume = Notification.Name("rb.capture.resume")
}
