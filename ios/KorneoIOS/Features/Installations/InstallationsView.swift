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
            case .done: return "Выполнены"
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
    @State private var isBound = false

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
                                Text("По текущему фильтру монтажей нет")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(filteredInstallations) { item in
                                NavigationLink {
                                    InstallationDetailView(viewModel: viewModel, item: item)
                                        .environmentObject(appState)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(installationTitle(item))
                                            .font(.headline)
                                        Text(installationStatusTitle(item.status))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let address = item.address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
            await ensureBoundAndLoad()
        }
        .onAppear {
            Task { await ensureBoundAndLoad() }
        }
        .onChange(of: appState.currentUser?.id) { _ in
            Task { await ensureBoundAndLoad() }
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
            Button(isDeleting ? "Удаляем..." : "Удалить", role: .destructive) {
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

    private func ensureBoundAndLoad() async {
        if !isBound {
            viewModel.bind(client: appState.client)
            isBound = true
        }
        await viewModel.load()
    }

    private func canDelete(item: Installation) -> Bool {
        guard let user = appState.currentUser else { return false }
        if user.role?.hasManagerRights == true { return true }
        return user.id == item.createdBy
    }

    private var visibleInstallations: [Installation] {
        guard let user = appState.currentUser else { return [] }
        if user.role != .worker {
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
                let normalized = (InstallationStatus.from(raw: item.status)?.rawValue ?? item.status ?? "").lowercased()
                return normalized == statusFilter.rawValue
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

    private func installationTitle(_ item: Installation) -> String {
        let clean = (item.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Без названия" : clean
    }

    private func installationStatusTitle(_ raw: String?) -> String {
        InstallationStatus.from(raw: raw)?.titleRu ?? "Неизвестно"
    }
}
