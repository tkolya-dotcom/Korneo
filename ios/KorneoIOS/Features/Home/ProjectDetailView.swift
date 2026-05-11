import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ProjectsViewModel
    @State var project: Project
    @State private var showEditSheet = false

    var body: some View {
        List {
            Section("Основное") {
                detailRow("Название", project.name ?? "-")
                detailRow("Статус", statusTitle(project.status))
                detailRow("Описание", project.description ?? "-")
            }
            Section("Бизнес") {
                detailRow("Клиент", project.clientName ?? "-")
                detailRow("Адрес", project.address ?? "-")
                detailRow("Бюджет", project.budget ?? "-")
            }
            Section("Даты") {
                detailRow("Начало", project.startDate ?? "-")
                detailRow("Окончание", project.endDate ?? "-")
            }
            Section("Метаданные") {
                detailRow("Создал", project.createdBy ?? "-")
                detailRow("Создан", project.createdAt ?? "-")
                detailRow("Обновлён", project.updatedAt ?? "-")
            }
        }
        .navigationTitle(project.name ?? "Проект")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canEdit {
                    Button("Редактировать") { showEditSheet = true }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ProjectFormView(viewModel: viewModel, mode: .edit(project))
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

    private func refreshLocal() async {
        await viewModel.load()
        if let updated = viewModel.projects.first(where: { $0.id == project.id }) {
            project = updated
        }
    }

    private var canEdit: Bool {
        guard let role = appState.currentUser?.role else { return false }
        return role != .engineer
    }

    private func statusTitle(_ raw: String?) -> String {
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "new": return "Новый"
        case "active": return "Активный"
        case "in_progress": return "В работе"
        case "pending": return "Ожидает"
        case "done", "completed": return "Завершён"
        case "cancelled": return "Отменён"
        default:
            let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? "-" : clean
        }
    }
}
