import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: TasksViewModel
    @State var task: TaskItem
    @State private var showEditSheet = false
    @State private var isUpdatingStatus = false
    @State private var projectsById: [String: String] = [:]
    @State private var usersById: [String: String] = [:]

    var body: some View {
        List {
            Section("Основное") {
                detailRow("Название", task.title ?? "-")
                detailRow("Статус", statusTitle(task.status))
                detailRow("Приоритет", TaskPriority.from(raw: task.priority).titleRu)
                detailRow("Описание", task.description ?? "-")
            }
            Section("Связи") {
                detailRow("Проект", projectName(task.projectId))
                detailRow("Исполнитель", userName(task.assigneeId))
                detailRow("Проект ID", task.projectId ?? "-")
                detailRow("Исполнитель ID", task.assigneeId ?? "-")
                detailRow("Создал", task.createdBy ?? "-")
            }
            Section("Даты") {
                detailRow("Срок", task.dueDate ?? "-")
                detailRow("Создано", task.createdAt ?? "-")
                detailRow("Обновлено", task.updatedAt ?? "-")
            }

            Section("Комментарии") {
                CommentsSectionView(
                    entityType: "task",
                    entityId: task.id,
                    currentUserId: appState.currentUser?.id,
                    client: appState.client
                )
            }

            Section("Статус") {
                if allowedTransitions.isEmpty {
                    Text("Нет доступных переходов")
                        .foregroundStyle(.secondary)
                } else if !canChangeStatus {
                    Text("У вашей роли нет прав на изменение статуса")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allowedTransitions) { next in
                        Button(isUpdatingStatus ? "Обновляем..." : "Перевести в «\(next.titleRu)»") {
                            Task { await changeStatus(next) }
                        }
                        .disabled(isUpdatingStatus)
                    }
                }
            }
        }
        .navigationTitle(task.title ?? "Задача")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canEdit {
                    Button("Изменить") { showEditSheet = true }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TaskFormView(viewModel: viewModel, mode: .edit(task))
                .environmentObject(appState)
        }
        .onChange(of: showEditSheet) { isShown in
            if !isShown {
                Task { await refreshLocal() }
            }
        }
        .task {
            await refreshLocal()
            await loadLookups()
        }
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

    private var allowedTransitions: [TaskStatus] {
        let fixed: [TaskStatus] = [.new, .inProgress, .waitingMaterials, .done, .postponed]
        let current = TaskStatus.from(raw: task.status)
        return fixed.filter { $0 != current }
    }

    private var canChangeStatus: Bool {
        canEdit
    }

    private var canEdit: Bool {
        guard let role = appState.currentUser?.role else { return false }
        return role != .engineer
    }

    private func statusTitle(_ raw: String?) -> String {
        if let mapped = TaskStatus.from(raw: raw) {
            return mapped.titleRu
        }
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "-" : clean
    }

    private func changeStatus(_ next: TaskStatus) async {
        guard canChangeStatus else { return }
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }
        let ok = await viewModel.updateStatus(task: task, to: next)
        if ok {
            await refreshLocal()
        }
    }

    private func refreshLocal() async {
        await viewModel.load()
        if let updated = viewModel.tasks.first(where: { $0.id == task.id }) {
            task = updated
        }
    }

    private func loadLookups() async {
        async let projectsReq = appState.client.fetchProjects()
        async let usersReq = appState.client.fetchUsers()
        let projects = (try? await projectsReq) ?? []
        let users = (try? await usersReq) ?? []

        projectsById = Dictionary(
            uniqueKeysWithValues: projects.map { project in
                let name = (project.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return (project.id, name.isEmpty ? project.id : name)
            }
        )
        usersById = Dictionary(
            uniqueKeysWithValues: users.map { user in
                let name = (user.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let email = (user.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let display = !name.isEmpty ? name : (!email.isEmpty ? email : user.id)
                return (user.id, display)
            }
        )
    }

    private func projectName(_ projectId: String?) -> String {
        let clean = (projectId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "Без проекта" }
        return projectsById[clean] ?? clean
    }

    private func userName(_ userId: String?) -> String {
        let clean = (userId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "Не назначен" }
        return usersById[clean] ?? clean
    }
}
