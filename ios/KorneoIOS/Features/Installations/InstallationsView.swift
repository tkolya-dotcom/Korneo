import SwiftUI

struct InstallationsView: View {
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
    @StateObject private var viewModel = InstallationsViewModel()

    @State private var showCreateSheet = false
    @State private var pendingDeleteItem: Installation?
    @State private var isDeleting = false
    @State private var searchText = ""
    @State private var statusFilter: StatusFilter = .all

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView("Загрузка монтажей...")
                } else if let error = viewModel.errorText, viewModel.items.isEmpty {
                    ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if visibleInstallations.isEmpty {
                    ContentUnavailableView("Нет монтажей", systemImage: "shippingbox")
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

                        if filteredInstallations.isEmpty {
                            Section {
                                Text("Нет подходящих монтажей")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(filteredInstallations) { item in
                                NavigationLink {
                                    InstallationDetailView(viewModel: viewModel, item: item)
                                        .environmentObject(appState)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title ?? "Untitled installation")
                                            .font(.headline)
                                        Text(statusTitle(item.status))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let address = item.address, !address.isEmpty {
                                            Text(address)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if canDelete(item: item) {
                                        Button(role: .destructive) {
                                            pendingDeleteItem = item
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
            .navigationTitle("Монтажи")
            .searchable(text: $searchText, prompt: "Поиск монтажей")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if canCreateInstallations {
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
            InstallationFormView(viewModel: viewModel, mode: .create)
                .environmentObject(appState)
        }
        .confirmationDialog(
            "Удалить монтаж?",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isDeleting ? "Удаление..." : "Удалить", role: .destructive) {
                guard let item = pendingDeleteItem else { return }
                Task {
                    isDeleting = true
                    defer { isDeleting = false }
                    let ok = await viewModel.delete(id: item.id)
                    if ok {
                        pendingDeleteItem = nil
                    }
                }
            }
            .disabled(isDeleting)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    private func canDelete(item: Installation) -> Bool {
        guard let user = appState.currentUser else { return false }
        if user.role?.hasManagerRights == true { return true }
        return user.id == item.createdBy
    }

    private var visibleInstallations: [Installation] {
        guard let user = appState.currentUser else { return [] }
        if user.role?.hasCoordinatorRights == true {
            return viewModel.items
        }
        return viewModel.items.filter { $0.assigneeId == user.id }
    }

    private var canCreateInstallations: Bool {
        appState.currentUser?.role?.hasCoordinatorRights == true
    }

    private var filteredInstallations: [Installation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return visibleInstallations.filter { item in
            let matchesStatus: Bool = {
                if statusFilter == .all { return true }
                return (item.status ?? "").lowercased() == statusFilter.rawValue
            }()

            let matchesSearch: Bool = {
                if query.isEmpty { return true }
                let haystack = [item.title, item.address, item.description]
                    .compactMap { $0?.lowercased() }
                    .joined(separator: " ")
                return haystack.contains(query)
            }()

            return matchesStatus && matchesSearch
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
            return clean.isEmpty ? "Новый" : clean
        }
    }
}
