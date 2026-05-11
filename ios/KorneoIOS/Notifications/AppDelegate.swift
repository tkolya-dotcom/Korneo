import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let dedupeWindowSeconds: TimeInterval = 2 * 60

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handlePushPayload(payload, enforceDedupe: false)
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationCenter.default.post(name: .pushDeviceTokenDidUpdate, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handlePushPayload(response.notification.request.content.userInfo, enforceDedupe: false)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        guard !shouldSkipPush(
            userInfo: userInfo,
            title: notification.request.content.title,
            body: notification.request.content.body,
            applyDedupe: true
        ) else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .badge, .sound])
    }

    private func handlePushPayload(_ payload: [AnyHashable: Any], enforceDedupe: Bool) {
        let title = firstNonEmpty([
            payload["title"] as? String,
            payload["sender_name"] as? String,
            payload["senderName"] as? String,
            payload["sender"] as? String,
            payload["user_name"] as? String,
            payload["chat_name"] as? String
        ])
        let body = firstNonEmpty([
            payload["body"] as? String,
            payload["message"] as? String,
            payload["text"] as? String,
            payload["content"] as? String
        ])

        if shouldSkipPush(userInfo: payload, title: title, body: body, applyDedupe: enforceDedupe) {
            return
        }

        let chatId = firstNonEmpty([
            payload["chat_id"] as? String,
            payload["chatId"] as? String,
            payload["open_chat_id"] as? String,
            payload["openChatId"] as? String
        ])
        let chatName = firstNonEmpty([
            payload["chat_name"] as? String,
            payload["name"] as? String
        ])
        guard let chatId, !chatId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        NotificationCenter.default.post(
            name: .pushOpenChatRequested,
            object: nil,
            userInfo: [
                "chat_id": chatId,
                "chat_name": chatName ?? ""
            ]
        )
    }

    private func shouldSkipPush(
        userInfo: [AnyHashable: Any],
        title: String?,
        body: String?,
        applyDedupe: Bool
    ) -> Bool {
        let defaults = UserDefaults.standard
        let currentUserId = (defaults.string(forKey: PushUserContextKeys.currentUserId) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let currentUserName = (defaults.string(forKey: PushUserContextKeys.currentUserName) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let senderId = firstNonEmpty([
            userInfo["sender_id"] as? String,
            userInfo["from_user_id"] as? String
        ])
        let recipientId = firstNonEmpty([
            userInfo["recipient_id"] as? String,
            userInfo["to_user_id"] as? String,
            userInfo["target_user_id"] as? String,
            userInfo["user_id"] as? String
        ])

        if !currentUserId.isEmpty,
           let senderId,
           currentUserId.caseInsensitiveCompare(senderId.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
            return true
        }

        if !currentUserId.isEmpty,
           let recipientId,
           currentUserId.caseInsensitiveCompare(recipientId.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame {
            return true
        }

        if !currentUserName.isEmpty,
           let title,
           currentUserName.caseInsensitiveCompare(title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
            return true
        }

        if !applyDedupe {
            return false
        }

        let now = Date().timeIntervalSince1970
        let dedupeRaw = firstNonEmpty([
            userInfo["dedupe_key"] as? String,
            userInfo["dedupeKey"] as? String,
            userInfo["message_id"] as? String,
            userInfo["messageId"] as? String
        ])
        let chatId = firstNonEmpty([
            userInfo["chat_id"] as? String,
            userInfo["chatId"] as? String
        ]) ?? ""

        let normalizedTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBody = (body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSender = senderId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let contentKey = sanitizeDedupeKey("\(chatId)|\(normalizedSender)|\(normalizedTitle)|\(normalizedBody)")
        let dedupeKey = sanitizeDedupeKey(dedupeRaw ?? contentKey)

        let lastDedupe = defaults.double(forKey: "korneo.push.dedupe.\(dedupeKey)")
        if lastDedupe > 0 && (now - lastDedupe) < dedupeWindowSeconds {
            return true
        }

        let lastContent = defaults.double(forKey: "korneo.push.content.\(contentKey)")
        if lastContent > 0 && (now - lastContent) < dedupeWindowSeconds {
            return true
        }

        defaults.set(now, forKey: "korneo.push.dedupe.\(dedupeKey)")
        defaults.set(now, forKey: "korneo.push.content.\(contentKey)")
        return false
    }

    private func sanitizeDedupeKey(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.|:-")
        let converted = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character("_") }
        let value = String(converted)
        if value.count <= 180 { return value }
        return String(value.prefix(180))
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            let clean = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                return clean
            }
        }
        return nil
    }
}
