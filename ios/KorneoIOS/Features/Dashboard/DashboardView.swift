import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Пользователь") {
                    statRow("Имя", appState.currentUser?.name ?? appState.currentUser?.email ?? "-")
                    statRow("Роль", appState.currentUser?.role?.rawValue ?? "-")
                }

                Section("Статистика") {
                    statRow("Проекты", viewModel.projectsCount)
                    statRow("Задачи", viewModel.tasksCount)
                    statRow("Монтажи", viewModel.installationsCount)
                    statRow("Заявки на материалы", viewModel.purchaseRequestsCount)
                }

                Section("Основное") {
                    if !isEngineer {
                        NavigationLink("Проекты") { ProjectsView() }
                    }
                    NavigationLink("Задачи") { TasksView() }
                    NavigationLink("Монтажи") { InstallationsView() }
                    NavigationLink("Заявки на материалы") { PurchaseRequestsView() }
                }

                Section("Навигация") {
                    NavigationLink("Пользователи") { UsersView() }
                    NavigationLink("Склад") { WarehouseView() }
                    NavigationLink("Каталог (Daichi)") { CatalogView() }
                    if hasElevatedRole {
                        NavigationLink("АВР") {
                            AvrView()
                        }
                        NavigationLink("Площадки") {
                            SitesView()
                        }
                    }
                    NavigationLink("АТСС") {
                        AtssView()
                    }
                    if !isEngineer {
                        NavigationLink("Архив") { ArchiveView() }
                    }
                    NavigationLink("Календарь") { CalendarView() }
                }

                if let error = viewModel.errorText {
                    Section("Ошибка") {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Главная")
            .refreshable {
                await viewModel.load(currentUser: appState.currentUser)
            }
        }
        .task {
            viewModel.bind(client: appState.client)
            await viewModel.load(currentUser: appState.currentUser)
        }
    }

    private func statRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)")
                .foregroundStyle(.secondary)
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var role: Role? {
        appState.currentUser?.role
    }

    private var hasElevatedRole: Bool {
        role?.hasCoordinatorRights == true
    }

    private var isEngineer: Bool {
        role == .engineer
    }
}
