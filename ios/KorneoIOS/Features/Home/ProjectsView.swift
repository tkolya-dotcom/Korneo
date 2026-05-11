import SwiftUI

struct ProjectsView: View {
    private enum StatusFilter: String, CaseIterable, Identifiable {
        case all
        case active
        case completed
        case pending

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Все"
            case .active: return "Активные"
            case .completed: return "Завершённые"
            case .pending: return "Ожидают"
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var showCreateSheet = false
    @State private var pendingDeleteProject: Project?
    @State private var isDeleting = false
    @State private var searchText = ""
    @State private var statusFilter: StatusFilter = .all

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.projects.isEmpty {
                    ProgressView("Загрузка проектов...")
                } else if let error = viewModel.errorText, viewModel.projects.isEmpty {
                    ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    List {
                        Section {
                            Picker("Статус", selection: $statusFilter) {
                                ForEach(StatusFilter.allCases) { filter in
                                    Text(filter.title).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if filteredProjects.isEmpty {
                            Section {
                                Text("Нет подходящих проектов")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(filteredProjects) { project in
                                NavigationLink {
                                    ProjectDetailView(viewModel: viewModel, project: project)
                                        .environmentObject(appState)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(project.name ?? "Проект без названия")
                                            .font(.headline)
                                        Text(statusTitle(project.status))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if canDelete(project: project) {
                                        Button(role: .destructive) {
                                            pendingDeleteProject = project
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .navigationTitle("Проекты")
            .searchable(text: $searchText, prompt: "Поиск проектов")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task {
            viewModel.bind(client: appState.client)
            await viewModel.load()
        }
        .sheet(isPresented: $showCreateSheet) {
            ProjectFormView(viewModel: viewModel, mode: .create)
                .environmentObject(appState)
        }
        .confirmationDialog(
            "Удалить проект?",
            isPresented: Binding(
                get: { pendingDeleteProject != nil },
                set: { if !$0 { pendingDeleteProject = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isDeleting ? "Удаление..." : "Удалить", role: .destructive) {
                guard let project = pendingDeleteProject else { return }
                Task {
                    isDeleting = true
                    defer { isDeleting = false }
                    let ok = await viewModel.delete(id: project.id)
                    if ok {
                        pendingDeleteProject = nil
                    }
                }
            }
            .disabled(isDeleting)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    private func canDelete(project: Project) -> Bool {
        guard let user = appState.currentUser else { return false }
        if user.role?.hasManagerRights == true { return true }
        return user.id == project.createdBy
    }

    private var filteredProjects: [Project] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.projects.filter { project in
            let matchesStatus: Bool = {
                if statusFilter == .all { return true }
                let status = (project.status ?? "").lowercased()
                return status == statusFilter.rawValue
            }()

            let matchesSearch: Bool = {
                if query.isEmpty { return true }
                let haystack = [
                    project.name,
                    project.description,
                    project.clientName,
                    project.address
                ]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
                return haystack.contains(query)
            }()

            return matchesStatus && matchesSearch
        }
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
