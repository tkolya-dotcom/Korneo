import Foundation

struct Installation: Codable, Identifiable {
    let id: String
    let projectId: String?
    let title: String?
    let description: String?
    let assigneeId: String?
    let status: String?
    let scheduledAt: String?
    let deadline: String?
    let address: String?
    let isArchived: Bool?
    let shortId: Int?
    let actualCompletionDate: String?
    let idPloshadki: String?
    let servisnyyId: String?
    let rayon: String?
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
        case scheduledAt = "scheduled_at"
        case deadline
        case address
        case isArchived = "is_archived"
        case shortId = "short_id"
        case actualCompletionDate = "actual_completion_date"
        case idPloshadki = "id_ploshadki"
        case servisnyyId = "servisnyy_id"
        case rayon
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum InstallationStatus: String, CaseIterable, Identifiable {
    case new
    case planned
    case inProgress = "in_progress"
    case done
    case received
    case archived
    case waitingMaterials = "waiting_materials"
    case inOrder = "in_order"
    case readyForReceipt = "ready_for_receipt"
    case postponed

    var id: String { rawValue }

    var titleRu: String {
        switch self {
        case .new: return "Новая"
        case .planned: return "Запланирована"
        case .inProgress: return "В работе"
        case .done: return "Выполнена"
        case .received: return "Принята"
        case .archived: return "В архиве"
        case .waitingMaterials: return "Ждёт материалы"
        case .inOrder: return "В заказе"
        case .readyForReceipt: return "Готова к приёмке"
        case .postponed: return "Отложена"
        }
    }

    static func from(raw value: String?) -> InstallationStatus? {
        let clean = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        return InstallationStatus(rawValue: clean)
    }

    static func allowedTransitions(from value: String?) -> [InstallationStatus] {
        guard let from = value.flatMap({ InstallationStatus(rawValue: $0) }) else {
            return [.new, .planned, .inProgress]
        }
        switch from {
        case .new:
            return [.planned, .inProgress]
        case .planned:
            return [.inProgress]
        case .inProgress:
            return [.waitingMaterials, .inOrder, .readyForReceipt, .postponed, .done]
        case .waitingMaterials, .inOrder, .postponed:
            return [.inProgress]
        case .readyForReceipt:
            return [.received]
        case .done:
            return [.received]
        case .received:
            return [.archived]
        case .archived:
            return []
        }
    }
}
