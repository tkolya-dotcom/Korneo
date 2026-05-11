import Foundation

struct Message: Codable, Identifiable {
    let id: String
    let chatId: String?
    let userId: String?
    let content: JSONValue?
    let type: String?
    let jobId: String?
    let isRead: Bool?
    let createdAt: String?
    let isDeleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case userId = "user_id"
        case content
        case type
        case jobId = "job_id"
        case isRead = "is_read"
        case createdAt = "created_at"
        case isDeleted = "is_deleted"
    }

    var contentText: String {
        if let contentObject, let text = contentObject["text"]?.textValue, !text.isEmpty {
            return text
        }
        return content?.textValue ?? ""
    }

    var contentObject: [String: JSONValue]? {
        guard case let .object(object)? = content else { return nil }
        return object
    }

    var replyPreviewText: String? {
        guard let contentObject else { return nil }
        let preview = contentObject["reply_text"]?.textValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return preview.isEmpty ? nil : preview
    }

    var forwardedFromName: String? {
        guard let contentObject else { return nil }
        let value = contentObject["forwarded_from_name"]?.textValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    var attachmentURL: String? {
        guard let contentObject else { return nil }
        let value = contentObject["url"]?.textValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    var attachmentFileName: String? {
        guard let contentObject else { return nil }
        let value = contentObject["file_name"]?.textValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    var reactionsText: String {
        guard let contentObject else { return "" }
        let direct = contentObject["reactions_text"]?.textValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !direct.isEmpty { return direct }
        guard case let .array(values)? = contentObject["reactions"] else { return "" }
        let list = values.map(\.textValue).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return list.joined(separator: " ")
    }
}
