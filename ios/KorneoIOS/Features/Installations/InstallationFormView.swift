import SwiftUI

struct InstallationFormView: View {
    enum Mode {
        case create
        case edit(Installation)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: InstallationsViewModel
    let mode: Mode

    @State private var title = ""
    @State private var details = ""
    @State private var address = ""
    @State private var idPloshadki = ""
    @State private var rayon = ""
    @State private var selectedProjectId = ""
    @State private var selectedAssigneeId = ""
    @State private var hasScheduledDate = false
    @State private var hasDeadlineDate = false
    @State private var scheduledDate = Date()
    @State private var deadlineDate = Date()
    @State private var selectedStatus: InstallationStatus = .new
    @State private var selectedType = "Стандартный монтаж"
    @State private var isSaving = false
    @State private var isLoadingLookups = false
    @State private var projects: [Project] = []
    @State private var users: [User] = []

    private let installationTypes = [
        "Стандартный монтаж",
        "Демонтаж",
        "Обслуживание",
        "Ремонт"
    ]

    private let editableStatuses: [InstallationStatus] = [
        .new,
        .planned,
        .inProgress,
        .waitingMaterials,
        .done,
        .postponed
    ]

    var body: some View {
        NavigationStack {
            Form {
                if isLoadingLookups {
                    ProgressView("Загрузка данных...")
                }

                Section("Основное") {
                    TextField("Название", text: $title)
                    TextField("Описание", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Адрес", text: $address)

                    Picker("Статус", selection: $selectedStatus) {
                        ForEach(statusOptions) { item in
                            Text(item.titleRu).tag(item)
                        }
                    }

                    Picker("Тип монтажа", selection: $selectedType) {
                        ForEach(installationTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }

                Section("Площадка") {
                    TextField("ID площадки", text: $idPloshadki)
                    TextField("Район", text: $rayon)
                }

                Section("Связи") {
                    Picker("Проект", selection: $selectedProjectId) {
                        Text("Без проекта").tag("")
                        ForEach(projects) { project in
                            Text(projectDisplayName(project)).tag(project.id)
                        }
                    }

                    Picker("Исполнитель", selection: $selectedAssigneeId) {
                        Text("Не назначен").tag("")
                        ForEach(users) { user in
                            Text(userDisplayName(user)).tag(user.id)
                        }
                    }
                }

                Section("Даты") {
                    Toggle("Указать плановую дату", isOn: $hasScheduledDate)
                    if hasScheduledDate {
                        DatePicker("План", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                    }

                    Toggle("Указать срок", isOn: $hasDeadlineDate)
                    if hasDeadlineDate {
                        DatePicker("Срок", selection: $deadlineDate, displayedComponents: [.date])
                    }
                }

                if let error = viewModel.errorText, !error.isEmpty {
                    Section("Ошибка") {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(modeTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Сохраняем..." : "Сохранить") {
                        Task { await save() }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isProjectValidForCurrentMode)
                }
            }
        }
        .onAppear {
            fillFromMode()
            Task { await loadLookups() }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .create: return "Новый монтаж"
        case .edit: return "Редактирование"
        }
    }

    private var statusOptions: [InstallationStatus] {
        editableStatuses
    }

    private var isCreateMode: Bool {
        if case .create = mode { return true }
        return false
    }

    private var isProjectValidForCurrentMode: Bool {
        if !isCreateMode { return true }
        return !selectedProjectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func fillFromMode() {
        guard case let .edit(item) = mode else { return }
        title = item.title ?? ""
        details = stripInstallationTypeLine(from: item.description)
        address = item.address ?? ""
        idPloshadki = item.idPloshadki ?? ""
        rayon = item.rayon ?? ""
        selectedProjectId = item.projectId ?? ""
        selectedAssigneeId = item.assigneeId ?? ""
        selectedStatus = InstallationStatus.from(raw: item.status) ?? .new
        if !statusOptions.contains(selectedStatus) {
            selectedStatus = .new
        }

        let parsedType = extractInstallationType(from: item.description)
        if !parsedType.isEmpty {
            selectedType = parsedType
        }

        if let parsedScheduled = parseDate(item.scheduledAt) {
            hasScheduledDate = true
            scheduledDate = parsedScheduled
        } else {
            hasScheduledDate = false
        }

        if let parsedDeadline = parseDate(item.deadline) {
            hasDeadlineDate = true
            deadlineDate = parsedDeadline
        } else {
            hasDeadlineDate = false
        }
    }

    private func loadLookups() async {
        isLoadingLookups = true
        defer { isLoadingLookups = false }

        async let projectsReq = appState.client.fetchProjects()
        async let usersReq = appState.client.fetchUsers()

        do {
            let (loadedProjects, loadedUsers) = try await (projectsReq, usersReq)
            projects = loadedProjects.sorted {
                projectDisplayName($0).localizedCaseInsensitiveCompare(projectDisplayName($1)) == .orderedAscending
            }
            users = loadedUsers.sorted {
                userDisplayName($0).localizedCaseInsensitiveCompare(userDisplayName($1)) == .orderedAscending
            }

            if !selectedProjectId.isEmpty && !projects.contains(where: { $0.id == selectedProjectId }) {
                selectedProjectId = ""
            }
            if !selectedAssigneeId.isEmpty && !users.contains(where: { $0.id == selectedAssigneeId }) {
                selectedAssigneeId = ""
            }
        } catch {
            projects = []
            users = []
        }
    }

    private func save() async {
        if isCreateMode && selectedProjectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.errorText = "Выберите проект"
            return
        }

        isSaving = true
        defer { isSaving = false }

        let payload = InstallationUpsertPayload(
            projectId: nilIfBlank(selectedProjectId),
            title: nilIfBlank(title),
            description: combineDescription(),
            assigneeId: nilIfBlank(selectedAssigneeId),
            status: selectedStatus.rawValue,
            scheduledAt: hasScheduledDate ? apiDateTimeString(scheduledDate) : nil,
            deadline: hasDeadlineDate ? apiDateString(deadlineDate) : nil,
            address: nilIfBlank(address),
            idPloshadki: nilIfBlank(idPloshadki),
            rayon: nilIfBlank(rayon),
            createdBy: {
                if case .create = mode {
                    return appState.currentUser?.id
                }
                return nil
            }()
        )

        let ok: Bool
        switch mode {
        case .create:
            ok = await viewModel.create(payload: payload)
        case let .edit(item):
            ok = await viewModel.update(id: item.id, payload: payload)
        }

        if ok {
            dismiss()
        }
    }

    private func combineDescription() -> String? {
        let cleanType = selectedType.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        var blocks: [String] = []
        if !cleanType.isEmpty {
            blocks.append("Тип монтажа: \(cleanType)")
        }
        if !cleanDetails.isEmpty {
            blocks.append(cleanDetails)
        }
        let final = blocks.joined(separator: "\n\n")
        return final.isEmpty ? nil : final
    }

    private func extractInstallationType(from description: String?) -> String {
        let text = (description ?? "")
        let prefix = "Тип монтажа:"
        for line in text.components(separatedBy: .newlines) {
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.hasPrefix(prefix) {
                let value = clean.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if installationTypes.contains(value) {
                    return value
                }
            }
        }
        return ""
    }

    private func stripInstallationTypeLine(from description: String?) -> String {
        let text = (description ?? "")
        let prefix = "Тип монтажа:"
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !$0.hasPrefix(prefix) }
        return lines.joined(separator: "\n")
    }

    private func projectDisplayName(_ project: Project) -> String {
        let name = project.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Проект \(project.id)" : name
    }

    private func userDisplayName(_ user: User) -> String {
        let name = user.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return email.isEmpty ? "Пользователь \(user.id)" : email
    }

    private func parseDate(_ raw: String?) -> Date? {
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        if let date = parser.date(from: clean) {
            return date
        }

        let iso = ISO8601DateFormatter()
        return iso.date(from: clean)
    }

    private func apiDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func apiDateTimeString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func nilIfBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
