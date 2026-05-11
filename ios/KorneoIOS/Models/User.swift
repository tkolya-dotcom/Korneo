import Foundation

struct User: Codable, Identifiable {
    let id: String
    let authUserId: String?
    let email: String?
    let name: String?
    let role: Role?
    let isOnline: Bool?
    let lastSeenAt: String?
    let phone: String?
    let avatarUrl: String?
    let notificationEnabled: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case authUserId = "auth_user_id"
        case email
        case name
        case role
        case isOnline = "is_online"
        case lastSeenAt = "last_seen_at"
        case phone
        case avatarUrl = "avatar_url"
        case notificationEnabled = "notification_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
