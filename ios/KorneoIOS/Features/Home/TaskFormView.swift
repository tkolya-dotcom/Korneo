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
    @State private var status = "new"
    @State private var projectId = ""
    @State private var assigneeId = ""
    @State private var dueDate = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Название", text: $title)
                    TextField("Описание", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Статус", text: $status)
                }
                Section("Связи") {
                    TextField("ID проекта", text: $projectId)
                    TextField("ID исполнителя", text: $assigneeId)
                    TextField("Срок (ISO)", text: $dueDate)
                }
            }
            .navigationTitle(modeTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Сохранение..." : "Сохранить") {
                        Task { await save() }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { preload() }
    }

    private var modeTitle: String {
        switch mode {
        case .create: return "Новая задача"
        case .edit: return "Редактирование задачи"
        }
    }

    private func preload() {
        guard case let .edit(task) = mode else { return }
        title = task.title ?? ""
        description = task.description ?? ""
        status = task.status ?? "new"
        projectId = task.projectId ?? ""
        assigneeId = task.assigneeId ?? ""
        dueDate = task.dueDate ?? ""
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let payload = TaskUpsertPayload(
            projectId: nilIfBlank(projectId),
            title: nilIfBlank(title),
            description: nilIfBlank(description),
            assigneeId: nilIfBlank(assigneeId),
            status: nilIfBlank(status),
            dueDate: nilIfBlank(dueDate),
            createdBy: appState.currentUser?.id
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

    private func nilIfBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
