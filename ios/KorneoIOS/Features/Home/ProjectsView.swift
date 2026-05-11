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
            case .all: return "All"
            case .active: return "Active"
            case .completed: return "Completed"
            case .pending: return "Pending"
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
                    ProgressView("Loading projects...")
                } else if let error = viewModel.errorText, viewModel.projects.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
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

                        if filteredProjects.isEmpty {
                            Section {
                                Text("No matching projects")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(filteredProjects) { project in
                                NavigationLink {
                                    ProjectDetailView(viewModel: viewModel, project: project)
                                        .environmentObject(appState)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(project.name ?? "Untitled project")
                                            .font(.headline)
                                        Text(project.status ?? "unknown")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if canDelete(project: project) {
                                        Button(role: .destructive) {
                                            pendingDeleteProject = project
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
            .navigationTitle("Projects")
            .searchable(text: $searchText, prompt: "Search projects")
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
            "Delete project?",
            isPresented: Binding(
                get: { pendingDeleteProject != nil },
                set: { if !$0 { pendingDeleteProject = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isDeleting ? "Deleting..." : "Delete", role: .destructive) {
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
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
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
}
