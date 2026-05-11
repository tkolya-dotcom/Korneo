import Foundation

extension PurchaseRequest {
    private static let archiveAfterSeconds: TimeInterval = 24 * 60 * 60
    private static let creatorEditableStatuses: Set<String> = ["draft", "pending", "rejected", "ready_for_receipt"]

    var normalizedStatus: String {
        (status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isArchiveStatus: Bool {
        switch normalizedStatus {
        case "received", "done", "completed", "finished":
            return true
        default:
            return false
        }
    }

    var archiveReferenceDate: Date? {
        parseRuleDate(receivedAt) ?? parseRuleDate(updatedAt) ?? parseRuleDate(createdAt)
    }

    func shouldMoveToArchive(now: Date = Date()) -> Bool {
        guard isArchiveStatus, let date = archiveReferenceDate else { return false }
        return now.timeIntervalSince(date) >= Self.archiveAfterSeconds
    }

    func canEdit(using user: User?) -> Bool {
        guard let user else { return false }
        let coordinator = user.role?.hasCoordinatorRights == true
        if coordinator { return true }

        let creator = user.id.trimmingCharacters(in: .whitespacesAndNewlines)
            == (createdBy ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !creator { return false }
        return Self.creatorEditableStatuses.contains(normalizedStatus)
    }

    private func parseRuleDate(_ raw: String?) -> Date? {
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        let normalized = clean.replacingOccurrences(of: "Z", with: "+00:00")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            parser.dateFormat = format
            if let parsed = parser.date(from: normalized) {
                return parsed
            }
        }
        return nil
    }
}
