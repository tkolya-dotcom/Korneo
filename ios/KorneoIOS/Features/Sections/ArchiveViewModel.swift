import Foundation
import Combine

@MainActor
final class ArchiveViewModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case tasks
        case installations
        case avr

        var id: String { rawValue }
    }

    struct Row: Identifiable {
        let id: String
        let title: String
        let statusLabel: String
        let subtitle: String
        let dateLabel: String
        let detailText: String
    }

    @Published private(set) var tasks: [Row] = []
    @Published private(set) var installations: [Row] = []
    @Published private(set) var avr: [Row] = []
    @Published private(set) var isLoading = false
    @Published var errorText: String?

    private var client: SupabaseClient?
    private let archiveAfter: TimeInterval = 24 * 60 * 60

    func bind(client: SupabaseClient) {
        self.client = client
    }

    func load() async {
        guard let client else {
            errorText = "Client is not configured"
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            async let taskRows = client.fetchTasks()
            async let installationRows = client.fetchInstallations()
            async let avrRows = client.fetchTableRows(
                table: "tasks_avr",
                select: "*",
                order: "updated_at.desc.nullslast",
                limit: 500
            )

            let fetchedTasks = try await taskRows
            let fetchedInstallations = try await installationRows
            let fetchedAvr = try await avrRows

            tasks = mapTasks(fetchedTasks)
            installations = mapInstallations(fetchedInstallations)
            avr = mapAvr(fetchedAvr)
        } catch {
            errorText = error.localizedDescription
        }
    }

    func unarchive(id: String, tab: Tab) async -> Bool {
        guard let client else { return false }
        do {
            switch tab {
            case .tasks:
                try await client.unarchiveTask(id: id)
            case .installations:
                try await client.unarchiveInstallation(id: id)
            case .avr:
                try await client.unarchiveAvr(id: id)
            }
            await load()
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    private func mapTasks(_ items: [TaskItem]) -> [Row] {
        items.compactMap { item in
            guard shouldIncludeArchive(
                isArchived: item.isArchived == true,
                status: item.status,
                dateCandidates: [item.updatedAt, item.dueDate, item.createdAt]
            ) else { return nil }

            let title = nonEmpty(item.title, fallback: "Task \(item.shortId.map(String.init) ?? item.id)")
            let status = taskStatusLabel(item.status)
            let subtitle = nonEmpty(item.description, fallback: item.projectId ?? "-")
            let date = displayDate(item.dueDate ?? item.updatedAt ?? item.createdAt)
            let detail = """
            Title: \(title)
            Status: \(status)
            Project: \(item.projectId ?? "-")
            Assignee: \(item.assigneeId ?? "-")
            Due: \(displayDate(item.dueDate))
            Created: \(displayDate(item.createdAt))
            Description: \(item.description ?? "-")
            """
            return Row(id: item.id, title: title, statusLabel: status, subtitle: subtitle, dateLabel: "Due: \(date)", detailText: detail)
        }
    }

    private func mapInstallations(_ items: [Installation]) -> [Row] {
        items.compactMap { item in
            guard shouldIncludeArchive(
                isArchived: item.isArchived == true,
                status: item.status,
                dateCandidates: [item.actualCompletionDate, item.updatedAt, item.scheduledAt, item.createdAt]
            ) else { return nil }

            let title = nonEmpty(item.title, fallback: "Installation \(item.shortId.map(String.init) ?? item.id)")
            let status = installationStatusLabel(item.status)
            let subtitle = nonEmpty(item.address, fallback: item.projectId ?? "-")
            let date = displayDate(item.scheduledAt ?? item.updatedAt ?? item.createdAt)
            let detail = """
            Title: \(title)
            Status: \(status)
            Project: \(item.projectId ?? "-")
            Assignee: \(item.assigneeId ?? "-")
            Date: \(displayDate(item.scheduledAt))
            Address: \(item.address ?? "-")
            Description: \(item.description ?? "-")
            """
            return Row(id: item.id, title: title, statusLabel: status, subtitle: subtitle, dateLabel: "Date: \(date)", detailText: detail)
        }
    }

    private func mapAvr(_ rows: [GenericRecord]) -> [Row] {
        rows.compactMap { row in
            let isArchived = asBool(row.fields["is_archived"]?.textValue)
            let status = nonEmpty(row.fields["status"]?.textValue, fallback: "")
            let dateCandidates = [
                row.fields["completed_at"]?.textValue,
                row.fields["status_changed_at"]?.textValue,
                row.fields["updated_at"]?.textValue,
                row.fields["date_to"]?.textValue,
                row.fields["created_at"]?.textValue
            ]
            guard shouldIncludeArchive(isArchived: isArchived, status: status, dateCandidates: dateCandidates) else {
                return nil
            }

            let title = firstNonEmpty([
                row.fields["title"]?.textValue,
                row.fields["type"]?.textValue,
                row.fields["equipment_type"]?.textValue,
                "AVR \(row.id)"
            ])
            let address = firstNonEmpty([
                row.fields["address_text"]?.textValue,
                row.fields["address"]?.textValue,
                row.fields["site_id"]?.textValue,
                "-"
            ])
            let responsible = firstNonEmpty([
                row.fields["responsible_name"]?.textValue,
                row.fields["executor_name"]?.textValue,
                row.fields["assignee_name"]?.textValue,
                row.fields["executor_id"]?.textValue,
                row.fields["assignee_id"]?.textValue,
                "-"
            ])
            let date = displayDate(firstNonEmpty([
                row.fields["date_from"]?.textValue,
                row.fields["created_at"]?.textValue,
                row.fields["updated_at"]?.textValue
            ]))
            let label = installationStatusLabel(status)
            let detail = """
            Title: \(title)
            Status: \(label)
            Address: \(address)
            Responsible: \(responsible)
            Created: \(displayDate(firstNonEmpty([row.fields["created_at"]?.textValue, row.fields["updated_at"]?.textValue])))
            Description: \(firstNonEmpty([row.fields["description"]?.textValue, row.fields["comment"]?.textValue, "-"]))
            """
            return Row(id: row.id, title: title, statusLabel: label, subtitle: "Address: \(address)", dateLabel: "Date: \(date)", detailText: detail)
        }
    }

    private func shouldIncludeArchive(isArchived: Bool, status: String?, dateCandidates: [String?]) -> Bool {
        if isArchived { return true }
        guard isDone(status) else { return false }
        guard let date = parseDate(firstNonEmpty(dateCandidates)) else { return false }
        return Date().timeIntervalSince(date) >= archiveAfter
    }

    private func isDone(_ status: String?) -> Bool {
        let value = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return value == "done" || value == "completed" || value == "finished"
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        if let date = ISO8601DateFormatter().date(from: value) { return date }

        let patterns = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
        for pattern in patterns {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = pattern
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private func displayDate(_ raw: String?) -> String {
        guard let date = parseDate(raw) else { return "-" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "dd.MM.yyyy"
        return out.string(from: date)
    }

    private func taskStatusLabel(_ status: String?) -> String {
        switch status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "new": return "New"
        case "planned": return "Planned"
        case "in_progress": return "In Progress"
        case "waiting_materials": return "Waiting Materials"
        case "done", "completed": return "Done"
        case "postponed": return "Postponed"
        case "cancelled": return "Cancelled"
        default: return nonEmpty(status, fallback: "-")
        }
    }

    private func installationStatusLabel(_ status: String?) -> String {
        switch status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "new": return "New"
        case "planned": return "Planned"
        case "in_progress": return "In Progress"
        case "waiting_materials": return "Waiting Materials"
        case "in_order": return "In Order"
        case "ready_for_receipt": return "Ready for Receipt"
        case "received": return "Received"
        case "done", "completed": return "Done"
        case "postponed": return "Postponed"
        case "cancelled": return "Cancelled"
        default: return nonEmpty(status, fallback: "-")
        }
    }

    private func asBool(_ value: String?) -> Bool {
        let normalized = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "true" || normalized == "1"
    }

    private func nonEmpty(_ value: String?, fallback: String) -> String {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? fallback : text
    }

    private func firstNonEmpty(_ values: [String?]) -> String {
        for value in values {
            let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty { return text }
        }
        return ""
    }
}
