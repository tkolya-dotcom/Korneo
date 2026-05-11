import Foundation

struct CommentAuthor: Codable {
    let id: String?
    let name: String?
    let email: String?
}

struct EntityComment: Codable, Identifiable {
    let rawId: String?
    let entityType: String?
    let entityId: String?
    let resourceType: String?
    let resourceId: String?
    let userId: String?
    let createdBy: String?
    let message: String?
    let content: String?
    let comment: String?
    let body: String?
    let text: String?
    let createdAt: String?
    let isDeleted: Bool?
    let user: CommentAuthor?

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case resourceType = "resource_type"
        case resourceId = "resource_id"
        case userId = "user_id"
        case createdBy = "created_by"
        case message
        case content
        case comment
        case body
        case text
        case createdAt = "created_at"
        case isDeleted = "is_deleted"
        case user
    }

    var id: String {
        rawId ?? "\(createdAt ?? "0")::\(displayAuthor)::\(displayText)"
    }

    var displayText: String {
        firstNonEmpty(message, content, comment, body, text)
    }

    var displayAuthor: String {
        firstNonEmpty(user?.name, user?.email, userId, createdBy, "User")
    }

    private func firstNonEmpty(_ values: String?...) -> String {
        for value in values {
            let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !clean.isEmpty {
                return clean
            }
        }
        return ""
    }
}
