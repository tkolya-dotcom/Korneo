import Foundation

struct ChatTypingStatus: Codable, Identifiable {
    let chatId: String
    let userId: String
    let isTyping: Bool
    let updatedAt: String?
    let user: ChatTypingUser?

    var id: String { "\(chatId)_\(userId)" }

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case userId = "user_id"
        case isTyping = "is_typing"
        case updatedAt = "updated_at"
        case user
    }
}

struct ChatTypingUser: Codable {
    let id: String?
    let name: String?
    let email: String?
}
