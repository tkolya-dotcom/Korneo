import SwiftUI

struct InstallationDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: InstallationsViewModel
    @State var item: Installation
    @State private var showEditSheet = false
    @State private var isUpdatingStatus = false
    @State private var projectNameById: [String: String] = [:]
    @State private var userNameById: [String: String] = [:]

    var body: some View {
        List {
            Section("Основное") {
                detailRow("Название", item.title ?? "-")
                detailRow("Статус", statusTitle(item.status))
                detailRow("Адрес", item.address ?? "-")
                detailRow("Описание", item.description ?? "-")
            }

            Section("Связи") {
                detailRow("Проект", relationLabel(id: item.projectId, namesById: projectNameById, fallbackPrefix: "Проект"))
                detailRow("Исполнитель", relationLabel(id: item.assigneeId, namesById: userNameById, fallbackPrefix: "Пользователь"))
                detailRow("Создал", relationLabel(id: item.createdBy, namesById: userNameById, fallbackPrefix: "Пользователь"))
            }

            Section("Площадка") {
                detailRow("ID площадки", valueOrDash(item.idPloshadki))
                detailRow("Район", valueOrDash(item.rayon))
            }

            Section("График") {
                detailRow("Запланировано", item.scheduledAt ?? "-")
                detailRow("Срок", item.deadline ?? "-")
                detailRow("Завершено", item.actualCompletionDate ?? "-")
            }

            Section("Комментарии") {
                CommentsSectionView(
                    entityType: "installation",
                    entityId: item.id,
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
        .navigationTitle(item.title ?? "Монтаж")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canEdit {
                    Button("Изменить") {
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
            await loadLookups()
        }
    }

    private var allowedTransitions: [InstallationStatus] {
        let fixed: [InstallationStatus] = [.new, .planned, .inProgress, .waitingMaterials, .done, .postponed]
        let current = InstallationStatus.from(raw: item.status)
        return fixed.filter { $0 != current }
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

    private func statusTitle(_ raw: String?) -> String {
        if let mapped = InstallationStatus.from(raw: raw) {
            return mapped.titleRu
        }
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "-" : clean
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

    private func loadLookups() async {
        async let projectsReq = appState.client.fetchProjects()
        async let usersReq = appState.client.fetchUsers()

        do {
            let (projects, users) = try await (projectsReq, usersReq)

            var newProjectMap: [String: String] = [:]
            for project in projects {
                let name = (project.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    newProjectMap[project.id] = name
                }
            }
            projectNameById = newProjectMap

            var newUserMap: [String: String] = [:]
            for user in users {
                let name = (user.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let email = (user.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let display = !name.isEmpty ? name : email
                if !display.isEmpty {
                    newUserMap[user.id] = display
                }
            }
            userNameById = newUserMap
        } catch {
            projectNameById = [:]
            userNameById = [:]
        }
    }

    private func relationLabel(id: String?, namesById: [String: String], fallbackPrefix: String) -> String {
        let cleanId = (id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return "-" }

        if let title = namesById[cleanId], !title.isEmpty {
            return "\(title) (\(cleanId))"
        }
        return "\(fallbackPrefix) \(cleanId)"
    }

    private func valueOrDash(_ raw: String?) -> String {
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "-" : clean
    }
}
