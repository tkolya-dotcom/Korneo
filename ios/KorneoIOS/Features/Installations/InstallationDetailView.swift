import SwiftUI

struct InstallationDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: InstallationsViewModel
    @State var item: Installation
    @State private var showEditSheet = false
    @State private var isUpdatingStatus = false

    var body: some View {
        List {
            Section("Основное") {
                detailRow("Название", item.title ?? "-")
                detailRow("Статус", statusTitle(item.status))
                detailRow("Адрес", item.address ?? "-")
                detailRow("Описание", item.description ?? "-")
            }

            Section("Связи") {
                detailRow("ID проекта", item.projectId ?? "-")
                detailRow("ID исполнителя", item.assigneeId ?? "-")
                detailRow("Создал", item.createdBy ?? "-")
            }

            Section("График") {
                detailRow("План", item.scheduledAt ?? "-")
                detailRow("Дедлайн", item.deadline ?? "-")
                detailRow("Факт завершения", item.actualCompletionDate ?? "-")
            }

            Section("Комментарии") {
                CommentsSectionView(
                    entityType: "installation",
                    entityId: item.id,
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
        .navigationTitle(item.title ?? "Монтаж")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canEdit {
                    Button("Редактировать") {
                        showEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            InstallationFormView(viewModel: viewModel, mode: .edit(item))
                .environmentObject(appState)
        }
        .onChange(of: showEditSheet) { isShown in
            if !isShown {
                Task { await refreshLocalItem() }
            }
        }
        .task {
            await refreshLocalItem()
        }
    }

    private var allowedTransitions: [InstallationStatus] {
        InstallationStatus.allowedTransitions(from: item.status)
    }

    private var canEdit: Bool {
        guard let role = appState.currentUser?.role else { return false }
        return role != .engineer
    }

    private var canChangeStatus: Bool {
        canEdit
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

    private func changeStatus(_ next: InstallationStatus) async {
        guard canChangeStatus else { return }
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }
        let ok = await viewModel.updateStatus(item: item, to: next)
        if ok {
            await refreshLocalItem()
        }
    }

    private func refreshLocalItem() async {
        await viewModel.load()
        if let updated = viewModel.items.first(where: { $0.id == item.id }) {
            item = updated
        }
    }

    private func statusTitle(_ raw: String?) -> String {
        switch (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "new": return "Новый"
        case "planned": return "Запланирован"
        case "in_progress": return "В работе"
        case "done", "completed": return "Выполнен"
        case "received": return "Принят"
        case "cancelled": return "Отменен"
        default:
            let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? "-" : clean
        }
    }
}
