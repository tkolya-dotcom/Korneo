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
            case .all: return "All"
            case .new: return "New"
            case .inProgress: return "In Progress"
            case .done: return "Done"
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
                    ProgressView("Loading installations...")
                } else if let error = viewModel.errorText, viewModel.items.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if visibleInstallations.isEmpty {
                    ContentUnavailableView("No installations", systemImage: "shippingbox")
                } else {
                    List {
                        Section {
                            Picker("Status", selection: $statusFilter) {
                                ForEach(StatusFilter.allCases) { filter in
                                    Text(filter.title).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if filteredInstallations.isEmpty {
                            Section {
                                Text("No matching installations")
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
                                        Text(item.status ?? "new")
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
                                            Label("Delete", systemImage: "trash")
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
            .navigationTitle("Installations")
            .searchable(text: $searchText, prompt: "Search installations")
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
            "Delete installation?",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isDeleting ? "Deleting..." : "Delete", role: .destructive) {
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
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
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
}
