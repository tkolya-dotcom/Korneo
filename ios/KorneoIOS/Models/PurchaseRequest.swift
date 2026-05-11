import Foundation

struct PurchaseRequest: Codable, Identifiable {
    let id: String
    let status: String?
    let installationId: String?
    let taskId: String?
    let taskAvrId: String?
    let projectId: String?
    let createdBy: String?
    let approvedBy: String?
    let totalAmount: Double?
    let comment: String?
    let receiptAddress: String?
    let receivedAt: String?
    let createdAt: String?
    let updatedAt: String?
    let shortId: Int?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case installationId = "installation_id"
        case taskId = "task_id"
        case taskAvrId = "task_avr_id"
        case projectId = "project_id"
        case createdBy = "created_by"
        case approvedBy = "approved_by"
        case totalAmount = "total_amount"
        case comment
        case receiptAddress = "receipt_address"
        case receivedAt = "received_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case shortId = "short_id"
        case title
    }
}

struct PurchaseRequestUpsertPayload: Codable {
    let status: String?
    let installationId: String?
    let taskId: String?
    let taskAvrId: String?
    let projectId: String?
    let createdBy: String?
    let comment: String?
    let receiptAddress: String?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case status
        case installationId = "installation_id"
        case taskId = "task_id"
        case taskAvrId = "task_avr_id"
        case projectId = "project_id"
        case createdBy = "created_by"
        case comment
        case receiptAddress = "receipt_address"
        case title
    }
}
