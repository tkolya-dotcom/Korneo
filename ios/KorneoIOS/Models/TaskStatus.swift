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
