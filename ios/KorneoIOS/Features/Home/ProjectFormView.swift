import SwiftUI

struct ProjectFormView: View {
    enum Mode {
        case create
        case edit(Project)
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProjectsViewModel
    let mode: Mode

    @State private var name = ""
    @State private var description = ""
    @State private var status = "new"
    @State private var clientName = ""
    @State private var address = ""
    @State private var budget = ""
    @State private var startDate = ""
    @State private var endDate = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(2...5)
                TextField("Status", text: $status)
                TextField("Client", text: $clientName)
                TextField("Address", text: $address)
                TextField("Budget", text: $budget)
                TextField("Start Date", text: $startDate)
                TextField("End Date", text: $endDate)
            }
            .navigationTitle(modeTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { preload() }
    }

    private var modeTitle: String {
        switch mode {
        case .create: return "New Project"
        case .edit: return "Edit Project"
        }
    }

    private func preload() {
        guard case let .edit(project) = mode else { return }
        name = project.name ?? ""
        description = project.description ?? ""
        status = project.status ?? "new"
        clientName = project.clientName ?? ""
        address = project.address ?? ""
        budget = project.budget ?? ""
        startDate = project.startDate ?? ""
        endDate = project.endDate ?? ""
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let payload = ProjectUpsertPayload(
            name: nilIfBlank(name),
            description: nilIfBlank(description),
            status: nilIfBlank(status),
            clientName: nilIfBlank(clientName),
            address: nilIfBlank(address),
            budget: nilIfBlank(budget),
            startDate: nilIfBlank(startDate),
            endDate: nilIfBlank(endDate),
            createdBy: appState.currentUser?.id
        )
        let ok: Bool
        switch mode {
        case .create:
            ok = await viewModel.create(payload: payload)
        case let .edit(project):
            ok = await viewModel.update(id: project.id, payload: payload)
        }
        if ok {
            dismiss()
        }
    }

    private func nilIfBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
