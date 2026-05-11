import SwiftUI

struct InstallationFormView: View {
    enum Mode {
        case create
        case edit(Installation)

        var title: String {
            switch self {
            case .create: return "Новый монтаж"
            case .edit: return "Редактирование монтажа"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: InstallationsViewModel
    let mode: Mode

    @State private var title = ""
    @State private var details = ""
    @State private var address = ""
    @State private var projectId = ""
    @State private var assigneeId = ""
    @State private var scheduledAt = ""
    @State private var deadline = ""
    @State private var status: InstallationStatus = .new
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Название", text: $title)
                    TextField("Описание", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Адрес", text: $address)
                }

                Section("Связи") {
                    TextField("ID проекта", text: $projectId)
                        .textInputAutocapitalization(.never)
                    TextField("ID исполнителя", text: $assigneeId)
                        .textInputAutocapitalization(.never)
                }

                Section("Даты") {
                    TextField("Плановая дата (ISO)", text: $scheduledAt)
                    TextField("Дедлайн (ISO)", text: $deadline)
                }

                Section("Статус") {
                    Picker("Статус", selection: $status) {
                        ForEach(InstallationStatus.allCases) { item in
                            Text(statusTitle(item)).tag(item)
                        }
                    }
                }

                if let error = viewModel.errorText {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode.title)
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
        .onAppear {
            fillFromMode()
        }
    }

    private func fillFromMode() {
        guard case let .edit(item) = mode else { return }
        title = item.title ?? ""
        details = item.description ?? ""
        address = item.address ?? ""
        projectId = item.projectId ?? ""
        assigneeId = item.assigneeId ?? ""
        scheduledAt = item.scheduledAt ?? ""
        deadline = item.deadline ?? ""
        status = InstallationStatus(rawValue: item.status ?? "") ?? .new
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let payload = InstallationUpsertPayload(
            projectId: nilIfBlank(projectId),
            title: nilIfBlank(title),
            description: nilIfBlank(details),
            assigneeId: nilIfBlank(assigneeId),
            status: status.rawValue,
            scheduledAt: nilIfBlank(scheduledAt),
            deadline: nilIfBlank(deadline),
            address: nilIfBlank(address),
            createdBy: appState.currentUser?.id
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

    private func nilIfBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func statusTitle(_ status: InstallationStatus) -> String {
        switch status {
        case .new: return "Новый"
        case .planned: return "Запланирован"
        case .inProgress: return "В работе"
        case .done: return "Выполнен"
        case .received: return "Принят"
        case .archived: return "В архиве"
        case .waitingMaterials: return "Ожидает материалы"
        case .inOrder: return "В заказе"
        case .readyForReceipt: return "Готов к приёмке"
        case .postponed: return "Отложен"
        }
    }
}
