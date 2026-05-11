import Foundation

struct ChatMemberRow: Codable {
    let chatId: String?
    let userId: String?
    let pinned: Bool?

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case userId = "user_id"
        case pinned
    }
}
