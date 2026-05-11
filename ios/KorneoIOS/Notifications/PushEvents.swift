import Foundation

extension Notification.Name {
    static let pushDeviceTokenDidUpdate = Notification.Name("pushDeviceTokenDidUpdate")
    static let pushOpenChatRequested = Notification.Name("pushOpenChatRequested")
}

enum PushUserContextKeys {
    static let currentUserId = "korneo.push.current_user_id"
    static let currentUserName = "korneo.push.current_user_name"
}
