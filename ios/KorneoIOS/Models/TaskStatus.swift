import Foundation

enum TaskStatus: String, CaseIterable, Identifiable {
    case new
    case planned
    case inProgress = "in_progress"
    case waitingMaterials = "waiting_materials"
    case done
    case postponed
    case cancelled

    var id: String { rawValue }

    var titleRu: String {
        switch self {
        case .new: return "Новая"
        case .planned: return "Запланирована"
        case .inProgress: return "В работе"
        case .waitingMaterials: return "Ждёт материалы"
        case .done: return "Выполнена"
        case .postponed: return "Отложена"
        case .cancelled: return "Отменена"
        }
    }

    static func from(raw value: String?) -> TaskStatus? {
        let clean = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        return TaskStatus(rawValue: clean)
    }

    static func allowedTransitions(from value: String?) -> [TaskStatus] {
        guard let from = value.flatMap({ TaskStatus(rawValue: $0) }) else {
            return [.new, .planned, .inProgress]
        }
        switch from {
        case .new:
            return [.planned, .inProgress, .postponed, .cancelled]
        case .planned:
            return [.inProgress, .postponed, .cancelled]
        case .inProgress:
            return [.waitingMaterials, .done, .postponed, .cancelled]
        case .waitingMaterials:
            return [.inProgress, .postponed, .cancelled]
        case .postponed:
            return [.inProgress, .cancelled]
        case .done, .cancelled:
            return []
        }
    }
}
