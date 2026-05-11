import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handlePushPayload(payload)
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
        handlePushPayload(response.notification.request.content.userInfo)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    private func handlePushPayload(_ payload: [AnyHashable: Any]) {
        let chatId = (payload["chat_id"] as? String) ?? (payload["open_chat_id"] as? String)
        let chatName = (payload["chat_name"] as? String) ?? (payload["name"] as? String)
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
}
