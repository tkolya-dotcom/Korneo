import Foundation
import UserNotifications
import UIKit

@MainActor
final class PushNotificationManager {
    private let keychain = KeychainStore()
    private let deviceTokenKey = "korneo.push.apns_token"

    var cachedDeviceToken: String? {
        keychain.loadText(forKey: deviceTokenKey)
    }

    func requestAuthorizationAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            #if DEBUG
            print("Push permission failed: \(error.localizedDescription)")
            #endif
        }
    }

    func saveDeviceToken(_ token: String) {
        keychain.saveText(token, forKey: deviceTokenKey)
    }
}
