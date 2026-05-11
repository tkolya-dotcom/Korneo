import SwiftUI

struct CalendarView: View {
    private struct EmployeeFilter: Identifiable, Hashable {
        let id: String
        let label: String
    }

    private struct CalendarWorkRow: Identifiable, Hashable {
        let id: String
        let dateKey: String
        let title: String
        let subtitle: String
    }

    @EnvironmentObject private var appState: AppState

    @State private var isLoading = false
    @State private var errorText: String?
    @State private var tasks: [TaskItem] = []
    @State private var installations: [Installation] = []
    @State private var avrRows: [GenericRecord] = []
    @State private var users: [User] = []

    @State private var visibleMonth: Date = {
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month], from: now)
        return Calendar.current.date(from: components) ?? now
    }()
    @State private var selectedDate = Date()
    @State private var selectedEmployeeId = ""

    private var canSeeAll: Bool {
        appState.currentUser?.role?.hasCoordinatorRights == true
    }

    private var managerFilterEnabled: Bool {
        appState.currentUser?.role?.hasManagerRights == true
    }

    private var employeeFilters: [EmployeeFilter] {
        var filters: [EmployeeFilter] = [.init(id: "", label: "Все сотрудники")]
        for user in users {
            let label = displayName(user)
            filters.append(.init(id: user.id, label: label))
        }
        return filters
    }

    private var eventsByDate: [String: [CalendarWorkRow]] {
        var map: [String: [CalendarWorkRow]] = [:]
        let currentUserId = appState.currentUser?.id ?? ""
        let selectedUserId = selectedEmployeeId.trimmingCharacters(in: .whitespacesAndNewlines)

        for task in tasks {
            if task.isArchived == true { continue }
            guard let dateKey = normalizedDateKey(task.dueDate) else { continue }
            let assigneeId = clean(task.assigneeId)

            if !selectedUserId.isEmpty {
                if assigneeId != selectedUserId { continue }
            } else if !canSeeAll && assigneeId != currentUserId {
                continue
            }

            let row = CalendarWorkRow(
                id: "task:\(task.id)",
                dateKey: dateKey,
                title: "Задача: \(safe(task.title))",
                subtitle: "Статус: \(taskStatus(task.status)) | Срок: \(displayDate(dateKey))"
            )
            map[dateKey, default: []].append(row)
        }

        for installation in installations {
            if installation.isArchived == true { continue }
            guard let dateKey = normalizedDateKey(installation.scheduledAt) else { continue }
            let assigneeId = clean(installation.assigneeId)

            if !selectedUserId.isEmpty {
                if assigneeId != selectedUserId { continue }
            } else if !canSeeAll && assigneeId != currentUserId {
                continue
            }

            let row = CalendarWorkRow(
                id: "installation:\(installation.id)",
                dateKey: dateKey,
                title: "Монтаж: \(safe(installation.title))",
                subtitle: "Статус: \(installationStatus(installation.status)) | \(safe(installation.address))"
            )
            map[dateKey, default: []].append(row)
        }

        for row in avrRows {
            if asBool(row.fields["is_archived"]) { continue }
            let dateCandidate = first(row, keys: ["date_from", "due_date", "planned_installation_date", "created_at"])
            guard let dateKey = normalizedDateKey(dateCandidate) else { continue }

            if !selectedUserId.isEmpty {
                if !isAvrAssigned(to: selectedUserId, row: row) { continue }
            } else if !canSeeAll {
                let createdBy = first(row, keys: ["created_by"])
                if !isAvrAssigned(to: currentUserId, row: row), createdBy != currentUserId {
                    continue
                }
            }

            let item = CalendarWorkRow(
                id: "avr:\(row.id)",
                dateKey: dateKey,
                title: "АВР: \(safe(first(row, keys: ["title", "type"])))",
                subtitle: "Статус: \(avrStatus(first(row, keys: ["status"]))) | \(safe(first(row, keys: ["address_text", "address", "equipment_type"])))"
            )
            map[dateKey, default: []].append(item)
        }

        return map
    }

    private var selectedDateKey: String {
        DateFormatter.yyyyMMdd.string(from: selectedDate)
    }

    private var selectedDayRows: [CalendarWorkRow] {
        eventsByDate[selectedDateKey] ?? []
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        let value = formatter.string(from: visibleMonth)
        return value.prefix(1).uppercased() + value.dropFirst()
    }

    private var monthCells: [Date] {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) ?? visibleMonth
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingEmpty = weekday == 1 ? 6 : (weekday - 2)
        let gridStart = calendar.date(byAdding: .day, value: -leadingEmpty, to: monthStart) ?? monthStart
        return (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if managerFilterEnabled {
                    Picker("Сотрудник", selection: $selectedEmployeeId) {
                        ForEach(employeeFilters) { item in
                            Text(item.label).tag(item.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Button {
                        shiftMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Spacer()
                    Text(monthTitle)
                        .font(.headline)
                    Spacer()

                    Button {
                        shiftMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(monthCells, id: \.self) { day in
                        dayCell(day)
                    }
                }

                Divider()

                Text("Работы на \(displayDate(selectedDateKey))")
                    .font(.headline)

                if isLoading {
                    ProgressView("Загрузка календаря...")
                } else if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if selectedDayRows.isEmpty {
                    Text("Нет работ на выбранный день")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(selectedDayRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(row.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Календарь")
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let calendar = Calendar.current
        let dayKey = DateFormatter.yyyyMMdd.string(from: day)
        let dayNumber = calendar.component(.day, from: day)
        let isInVisibleMonth = calendar.component(.month, from: day) == calendar.component(.month, from: visibleMonth)
        let isSelected = dayKey == selectedDateKey
        let count = eventsByDate[dayKey]?.count ?? 0

        Button {
            selectedDate = day
            visibleMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) ?? visibleMonth
        } label: {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.caption)
                    .foregroundStyle(isInVisibleMonth ? Color.primary : Color.secondary)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(by delta: Int) {
        let calendar = Calendar.current
        visibleMonth = calendar.date(byAdding: .month, value: delta, to: visibleMonth) ?? visibleMonth
        selectedDate = visibleMonth
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        errorText = nil
        do {
            async let tasksReq = appState.client.fetchTasks()
            async let installationsReq = appState.client.fetchInstallations()
            async let avrReq = appState.client.fetchTableRows(table: "tasks_avr", select: "*", order: nil, limit: 1000)
            async let usersReq = appState.client.fetchUsers()

            tasks = try await tasksReq
            installations = try await installationsReq
            avrRows = try await avrReq
            users = try await usersReq
                .sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func isAvrAssigned(to userId: String, row: GenericRecord) -> Bool {
        let cleanUserId = clean(userId)
        if cleanUserId.isEmpty { return false }
        let executorId = first(row, keys: ["executor_id"])
        let assigneeId = first(row, keys: ["assignee_id"])
        if executorId == cleanUserId || assigneeId == cleanUserId {
            return true
        }
        let engineerIds = parseIds(row.fields["engineer_ids"]) + parseIds(row.fields["executor_ids"])
        return engineerIds.contains(cleanUserId)
    }

    private func parseIds(_ value: JSONValue?) -> [String] {
        guard let value else { return [] }
        switch value {
        case let .array(values):
            return values.map { clean($0.textValue) }.filter { !$0.isEmpty }
        case let .string(text):
            return text
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .split(separator: ",")
                .map { clean(String($0)) }
                .filter { !$0.isEmpty }
        default:
            return []
        }
    }

    private func normalizedDateKey(_ raw: String?) -> String? {
        let value = clean(raw)
        if value.isEmpty { return nil }
        if value.count >= 10, value.contains("-") {
            return String(value.prefix(10))
        }
        if value.count == 8, Int(value) != nil, value.hasPrefix("20") {
            let y = value.prefix(4)
            let m = value.dropFirst(4).prefix(2)
            let d = value.suffix(2)
            return "\(y)-\(m)-\(d)"
        }
        return nil
    }

    private func displayDate(_ yyyyMMdd: String) -> String {
        if let date = DateFormatter.yyyyMMdd.date(from: yyyyMMdd) {
            return DateFormatter.ddMMyyyy.string(from: date)
        }
        if yyyyMMdd.count >= 10, yyyyMMdd.contains("-") {
            return String(yyyyMMdd.prefix(10).split(separator: "-").reversed().joined(separator: "."))
        }
        return yyyyMMdd
    }

    private func first(_ row: GenericRecord, keys: [String]) -> String {
        for key in keys {
            let value = clean(row.fields[key]?.textValue)
            if !value.isEmpty {
                return value
            }
        }
        return ""
    }

    private func asBool(_ value: JSONValue?) -> Bool {
        clean(value?.textValue).lowercased() == "true"
    }

    private func displayName(_ user: User) -> String {
        let name = clean(user.name)
        if !name.isEmpty { return name }
        let email = clean(user.email)
        if !email.isEmpty { return email }
        return user.id
    }

    private func taskStatus(_ raw: String?) -> String {
        switch clean(raw).lowercased() {
        case "new": return "Новая"
        case "in_progress": return "В работе"
        case "waiting_materials": return "Ждет материалы"
        case "done", "completed": return "Выполнена"
        case "cancelled": return "Отменена"
        default: return safe(raw)
        }
    }

    private func installationStatus(_ raw: String?) -> String {
        switch clean(raw).lowercased() {
        case "new": return "Новый"
        case "planned": return "Запланирован"
        case "in_progress": return "В работе"
        case "done", "completed": return "Выполнен"
        case "received": return "Принят"
        case "cancelled": return "Отменен"
        default: return safe(raw)
        }
    }

    private func avrStatus(_ raw: String?) -> String {
        switch clean(raw).lowercased() {
        case "new": return "Новая"
        case "planned": return "Запланировано"
        case "in_progress": return "В работе"
        case "waiting_materials": return "Ждет материалы"
        case "done", "completed": return "Выполнено"
        case "postponed": return "Отложено"
        default: return safe(raw)
        }
    }

    private func safe(_ value: String?) -> String {
        let cleanValue = clean(value)
        return cleanValue.isEmpty ? "-" : cleanValue
    }

    private func clean(_ value: String?) -> String {
        let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.lowercased() == "null" ? "" : raw
    }
}

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let ddMMyyyy: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}
