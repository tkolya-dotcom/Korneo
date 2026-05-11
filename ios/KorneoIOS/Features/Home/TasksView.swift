import SwiftUI

struct TasksView: View {
    private enum StatusFilter: String, CaseIterable, Identifiable {
        case all
        case new
        case inProgress = "in_progress"
        case done

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Все"
            case .new: return "Новые"
            case .inProgress: return "В работе"
            case .done: return "Выполненные"
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = TasksViewModel()
    @State private var showCreateSheet = false
    @State private var pendingDeleteTask: TaskItem?
    @State private var isDeleting = false
    @State private var searchText = ""
    @State private var statusFilter: StatusFilter = .all

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    ProgressView("Загрузка задач...")
                } else if let error = viewModel.errorText, viewModel.tasks.isEmpty {
                    ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if visibleTasks.isEmpty {
                    ContentUnavailableView("Нет задач", systemImage: "checkmark.circle")
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

                        if filteredTasks.isEmpty {
                            Section {
                                Text("Нет подходящих задач")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(filteredTasks) { task in
                                NavigationLink {
                                    TaskDetailView(viewModel: viewModel, task: task)
                                        .environmentObject(appState)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title ?? "Задача без названия")
                                            .font(.headline)
                                        Text(statusTitle(task.status))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if canDelete(task: task) {
                                        Button(role: .destructive) {
                                            pendingDeleteTask = task
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
            .navigationTitle("Задачи")
            .searchable(text: $searchText, prompt: "Поиск задач")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if canCreateTasks {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .task {
            viewModel.bind(client: appState.client)
            await viewModel.load()
        }
        .sheet(isPresented: $showCreateSheet) {
            TaskFormView(viewModel: viewModel, mode: .create)
                .environmentObject(appState)
        }
        .confirmationDialog(
            "Удалить задачу?",
            isPresented: Binding(
                get: { pendingDeleteTask != nil },
                set: { if !$0 { pendingDeleteTask = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isDeleting ? "Удаление..." : "Удалить", role: .destructive) {
                guard let task = pendingDeleteTask else { return }
                Task {
                    isDeleting = true
                    defer { isDeleting = false }
                    let ok = await viewModel.delete(id: task.id)
                    if ok {
                        pendingDeleteTask = nil
                    }
                }
            }
            .disabled(isDeleting)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    private func canDelete(task: TaskItem) -> Bool {
        guard let user = appState.currentUser else { return false }
        if user.role?.hasManagerRights == true { return true }
        return user.id == task.createdBy
    }

    private var visibleTasks: [TaskItem] {
        guard let user = appState.currentUser else { return [] }
        if user.role?.hasCoordinatorRights == true {
            return viewModel.tasks
        }
        return viewModel.tasks.filter { $0.assigneeId == user.id }
    }

    private var canCreateTasks: Bool {
        appState.currentUser?.role?.hasCoordinatorRights == true
    }

    private var filteredTasks: [TaskItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return visibleTasks.filter { task in
            let matchesStatus: Bool = {
                if statusFilter == .all { return true }
                return (task.status ?? "").lowercased() == statusFilter.rawValue
            }()

            let matchesSearch: Bool = {
                if query.isEmpty { return true }
                let haystack = [task.title, task.description]
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
