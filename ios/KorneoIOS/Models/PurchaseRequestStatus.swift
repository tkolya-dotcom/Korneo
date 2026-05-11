import Foundation

enum PurchaseRequestStatus: String, CaseIterable, Identifiable {
    case draft
    case pending
    case approved
    case rejected
    case inOrder = "in_order"
    case readyForReceipt = "ready_for_receipt"
    case received
    case done

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .draft: return "Черновик"
        case .pending: return "Ожидает согласования"
        case .approved: return "Одобрено"
        case .rejected: return "Отклонено"
        case .inOrder: return "В заказе"
        case .readyForReceipt: return "Готово к получению"
        case .received: return "Получено"
        case .done: return "Завершено"
        }
    }

    static func allowedTransitions(from value: String?) -> [PurchaseRequestStatus] {
        guard let from = value.flatMap({ PurchaseRequestStatus(rawValue: $0) }) else {
            return [.draft, .pending]
        }
        switch from {
        case .draft:
            return [.pending, .rejected]
        case .pending:
            return [.approved, .rejected]
        case .approved:
            return [.inOrder, .readyForReceipt, .rejected]
        case .inOrder:
            return [.readyForReceipt, .rejected]
        case .readyForReceipt:
            return [.received, .rejected]
        case .received:
            return [.done]
        case .rejected:
            return [.draft]
        case .done:
            return []
        }
    }
}
