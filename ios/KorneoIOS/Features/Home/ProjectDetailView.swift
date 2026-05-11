import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ProjectsViewModel
    @State var project: Project
    @State private var showEditSheet = false

    var body: some View {
        List {
            Section("Main") {
                detailRow("Name", project.name ?? "-")
                detailRow("Status", project.status ?? "-")
                detailRow("Description", project.description ?? "-")
            }
            Section("Business") {
                detailRow("Client", project.clientName ?? "-")
                detailRow("Address", project.address ?? "-")
                detailRow("Budget", project.budget ?? "-")
            }
            Section("Dates") {
                detailRow("Start", project.startDate ?? "-")
                detailRow("End", project.endDate ?? "-")
            }
            Section("Meta") {
                detailRow("Created By", project.createdBy ?? "-")
                detailRow("Created", project.createdAt ?? "-")
                detailRow("Updated", project.updatedAt ?? "-")
            }
        }
        .navigationTitle(project.name ?? "Project")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canEdit {
                    Button("Edit") { showEditSheet = true }
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
}
