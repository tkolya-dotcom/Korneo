import Foundation

struct ChatMemberUserRow: Codable {
    let chatId: String?
    let userId: String?
    let user: ChatTypingUser?

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case userId = "user_id"
        case user
    }
}
