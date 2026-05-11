import Foundation

struct Chat: Codable, Identifiable {
    let id: String
    let type: String?
    let name: String?
    let createdBy: String?
    let createdAt: String?
    let updatedAt: String?
    let isDeleted: Bool?
    let pinned: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
        case pinned
    }
}
