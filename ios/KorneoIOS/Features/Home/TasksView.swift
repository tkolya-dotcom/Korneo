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
            case .done: return "Выполнены"
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
    @State private var isBound = false

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
                                Text("По текущему фильтру задач нет")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(filteredTasks) { task in
                                NavigationLink {
                                    TaskDetailView(viewModel: viewModel, task: task)
                                        .environmentObject(appState)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(taskTitle(task))
                                            .font(.headline)
                                        HStack(spacing: 8) {
                                            Text(statusLabel(task.status))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(TaskPriority.from(raw: task.priority).titleRu)
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(.thinMaterial)
                                                .clipShape(Capsule())
                                        }
                                        if let dueDate = formattedDueDate(task.dueDate) {
                                            Text("Срок: \(dueDate)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
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
            await ensureBoundAndLoad()
        }
        .onAppear {
            Task { await ensureBoundAndLoad() }
        }
        .onChange(of: appState.selectedTab) { tab in
            guard tab == .tasks else { return }
            Task { await viewModel.load() }
        }
        .onChange(of: appState.currentUser?.id) { _ in
            Task { await ensureBoundAndLoad() }
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
            Button(isDeleting ? "Удаляем..." : "Удалить", role: .destructive) {
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

    private func ensureBoundAndLoad() async {
        if !isBound {
            viewModel.bind(client: appState.client)
            isBound = true
        }
        await viewModel.load()
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
                let raw = (TaskStatus.from(raw: task.status)?.rawValue ?? task.status ?? "").lowercased()
                return raw == statusFilter.rawValue
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

    private func statusLabel(_ raw: String?) -> String {
        TaskStatus.from(raw: raw)?.titleRu ?? "Неизвестно"
    }

    private func taskTitle(_ task: TaskItem) -> String {
        let clean = (task.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Без названия" : clean
    }

    private func formattedDueDate(_ raw: String?) -> String? {
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if clean.count >= 10, clean[clean.index(clean.startIndex, offsetBy: 4)] == "-" {
            let year = clean.prefix(4)
            let monthStart = clean.index(clean.startIndex, offsetBy: 5)
            let monthEnd = clean.index(clean.startIndex, offsetBy: 7)
            let dayStart = clean.index(clean.startIndex, offsetBy: 8)
            let dayEnd = clean.index(clean.startIndex, offsetBy: 10)
            let month = clean[monthStart..<monthEnd]
            let day = clean[dayStart..<dayEnd]
            return "\(day).\(month).\(year)"
        }
        return clean
    }
}
