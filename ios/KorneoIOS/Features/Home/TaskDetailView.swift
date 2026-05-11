import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: TasksViewModel
    @State var task: TaskItem
    @State private var showEditSheet = false
    @State private var isUpdatingStatus = false

    var body: some View {
        List {
            Section("Основное") {
                detailRow("Название", task.title ?? "-")
                detailRow("Статус", statusTitle(task.status))
                detailRow("Описание", task.description ?? "-")
            }
            Section("Связи") {
                detailRow("ID проекта", task.projectId ?? "-")
                detailRow("ID исполнителя", task.assigneeId ?? "-")
                detailRow("Создал", task.createdBy ?? "-")
            }
            Section("Даты") {
                detailRow("Срок", task.dueDate ?? "-")
                detailRow("Создана", task.createdAt ?? "-")
                detailRow("Обновлена", task.updatedAt ?? "-")
            }

            Section("Комментарии") {
                CommentsSectionView(
                    entityType: "task",
                    entityId: task.id,
                    currentUserId: appState.currentUser?.id,
                    client: appState.client
                )
            }

            Section("Переход статуса") {
                if allowedTransitions.isEmpty {
                    Text("Нет доступных переходов")
                        .foregroundStyle(.secondary)
                } else if !canChangeStatus {
                    Text("Изменение статуса недоступно для вашей роли")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allowedTransitions) { next in
                        Button(isUpdatingStatus ? "Обновление..." : "Перевести в: \(statusTitle(next.rawValue))") {
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
                    Button("Редактировать") { showEditSheet = true }
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
        TaskStatus.allowedTransitions(from: task.status)
    }

    private var canChangeStatus: Bool {
        canEdit
    }

    private var canEdit: Bool {
        guard let role = appState.currentUser?.role else { return false }
        return role != .engineer
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

    private func statusTitle(_ raw: String?) -> String {
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "new": return "Новая"
        case "planned": return "Запланирована"
        case "in_progress": return "В работе"
        case "waiting_materials": return "Ждёт материалы"
        case "done", "completed": return "Выполнена"
        case "postponed": return "Отложена"
        case "cancelled": return "Отменена"
        default:
            let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? "-" : clean
        }
    }
}
