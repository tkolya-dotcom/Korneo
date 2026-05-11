import Foundation

struct TaskItem: Codable, Identifiable {
    let id: String
    let projectId: String?
    let title: String?
    let description: String?
    let assigneeId: String?
    let status: String?
    let priority: String?
    let dueDate: String?
    let isArchived: Bool?
    let shortId: Int?
    let createdBy: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case title
        case description
        case assigneeId = "assignee_id"
        case status
        case priority
        case dueDate = "due_date"
        case isArchived = "is_archived"
        case shortId = "short_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
