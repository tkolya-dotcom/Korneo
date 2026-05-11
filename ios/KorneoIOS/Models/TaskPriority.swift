import Foundation

enum TaskPriority: String, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case urgent

    var id: String { rawValue }

    var titleRu: String {
        switch self {
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        case .urgent: return "Срочно"
        }
    }

    static func from(raw value: String?) -> TaskPriority {
        let normalized = (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return TaskPriority(rawValue: normalized) ?? .medium
    }
}
