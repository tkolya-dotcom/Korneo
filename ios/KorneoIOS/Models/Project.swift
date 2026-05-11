import Foundation

struct Project: Codable, Identifiable {
    let id: String
    let name: String?
    let description: String?
    let status: String?
    let clientName: String?
    let address: String?
    let budget: String?
    let startDate: String?
    let endDate: String?
    let createdBy: String?
    let shortId: Int?
    let isArchived: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case status
        case clientName = "client_name"
        case address
        case budget
        case startDate = "start_date"
        case endDate = "end_date"
        case createdBy = "created_by"
        case shortId = "short_id"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
