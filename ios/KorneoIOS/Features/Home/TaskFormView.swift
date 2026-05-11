import SwiftUI

struct TaskFormView: View {
    enum Mode {
        case create
        case edit(TaskItem)
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasksViewModel
    let mode: Mode

    @State private var title = ""
    @State private var description = ""
    @State private var selectedStatus: TaskStatus = .new
    @State private var selectedPriority: TaskPriority = .medium
    @State private var selectedProjectId = ""
    @State private var selectedAssigneeId = ""
    @State private var hasDueDate = false
    @State private var selectedDueDate = Date()
    @State private var isSaving = false
    @State private var isLoadingLookups = false
    @State private var projects: [Project] = []
    @State private var users: [User] = []
    private let editStatusOptions: [TaskStatus] = [.new, .inProgress, .waitingMaterials, .done, .postponed]

    var body: some View {
        NavigationStack {
            Form {
                if isLoadingLookups {
                    ProgressView("Загрузка данных...")
                }

                Section("Основное") {
                    TextField("Название", text: $title)
                    TextField("Описание", text: $description, axis: .vertical)
                        .lineLimit(2...5)

                    if isCreateMode {
                        detailRow("Статус", TaskStatus.new.titleRu)
                    } else {
                        Picker("Статус", selection: $selectedStatus) {
                            ForEach(editStatusOptions) { status in
                                Text(status.titleRu).tag(status)
                            }
                        }
                    }

                    Picker("Приоритет", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.titleRu).tag(priority)
                        }
                    }
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

                Section("Срок") {
                    Toggle("Указать дату", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "Дата",
                            selection: $selectedDueDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                    }
                }

                if let error = viewModel.errorText, !error.isEmpty {
                    Section("Ошибка") {
                        Text(error)
                            .foregroundStyle(.red)
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
            preload()
            Task { await loadLookups() }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .create: return "Новая задача"
        case .edit: return "Редактирование"
        }
    }

    private func preload() {
        guard case let .edit(task) = mode else {
            selectedStatus = .new
            selectedPriority = .medium
            return
        }
        title = task.title ?? ""
        description = task.description ?? ""
        selectedStatus = TaskStatus.from(raw: task.status) ?? .new
        if !editStatusOptions.contains(selectedStatus) {
            selectedStatus = .new
        }
        selectedPriority = TaskPriority.from(raw: task.priority)
        selectedProjectId = task.projectId ?? ""
        selectedAssigneeId = task.assigneeId ?? ""

        if let parsedDate = parseDueDate(task.dueDate) {
            hasDueDate = true
            selectedDueDate = parsedDate
        } else {
            hasDueDate = false
        }
    }

    private func loadLookups() async {
        isLoadingLookups = true
        defer { isLoadingLookups = false }

        async let projectsReq = appState.client.fetchProjects()
        async let usersReq = appState.client.fetchUsers()

        do {
            let (loadedProjects, loadedUsers) = try await (projectsReq, usersReq)
            projects = loadedProjects.sorted { projectDisplayName($0).localizedCaseInsensitiveCompare(projectDisplayName($1)) == .orderedAscending }
            users = loadedUsers.sorted { userDisplayName($0).localizedCaseInsensitiveCompare(userDisplayName($1)) == .orderedAscending }

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

        let dueDateValue: String? = hasDueDate ? apiDateString(from: selectedDueDate) : nil
        let createdByValue: String? = {
            if case .create = mode {
                return appState.currentUser?.id
            }
            return nil
        }()

        let payload = TaskUpsertPayload(
            projectId: nilIfBlank(selectedProjectId),
            title: nilIfBlank(title),
            description: nilIfBlank(description),
            assigneeId: nilIfBlank(selectedAssigneeId),
            status: isCreateMode ? TaskStatus.new.rawValue : selectedStatus.rawValue,
            priority: selectedPriority.rawValue,
            dueDate: dueDateValue,
            createdBy: createdByValue
        )

        let ok: Bool
        switch mode {
        case .create:
            ok = await viewModel.create(payload: payload)
        case let .edit(task):
            ok = await viewModel.update(id: task.id, payload: payload)
        }

        if ok {
            dismiss()
        }
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

    private func parseDueDate(_ raw: String?) -> Date? {
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        if let date = parser.date(from: clean) {
            return date
        }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: clean) {
            return date
        }
        return nil
    }

    private func apiDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func nilIfBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var isCreateMode: Bool {
        if case .create = mode { return true }
        return false
    }

    private var isProjectValidForCurrentMode: Bool {
        if !isCreateMode { return true }
        return !selectedProjectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }
}
